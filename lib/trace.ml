type field  = Rfc5322.trace

type word = Rfc822.word
type local = Rfc822.local
type phrase = Rfc5322.phrase

type literal_domain = Rfc5321.literal_domain =
  | IPv4 of Ipaddr.V4.t
  | IPv6 of Ipaddr.V6.t
  | Ext of string * string

type domain = Rfc5322.domain

type mailbox = Rfc5322.mailbox =
  { name : phrase option
  ; local : local
  ; domain : domain * domain list }

type t =
  { index : Number.t
  ; trace : mailbox option
  ; received : (received list * Date.t option) list
  ; location : Location.t }
and received =
  [ `Addr of mailbox
  | `Domain of domain
  | `Word of word ]

module Value = struct
  type t =
    | Received : (received list * Date.t option) -> t
    | ReturnPath : Mailbox.t -> t

  let pp_received ppf = function
    | `Addr x -> Mailbox.pp ppf x
    | `Domain x -> Mailbox.pp_domain ppf x
    | `Word x -> Mailbox.pp_word ppf x

  let pp ppf = function
    | ReturnPath x -> Mailbox.pp ppf x
    | Received x -> Fmt.(Dump.pair (Dump.list pp_received) (Dump.option Date.pp)) ppf x
end

let number { index; _ } = index
let location { location; _ } = location

let pp_trace ppf (local, (x, r)) = match r with
  | [] ->
    Fmt.pf ppf "{ @[<hov>local = %a;@ domain = %a@] }"
      Mailbox.pp_local local Mailbox.pp_domain x
  | domains ->
    Fmt.pf ppf "{ @[<hov>local = %a;@ domains = %a@] }"
      Mailbox.pp_local local
      Fmt.(hvbox (Dump.list Mailbox.pp_domain)) (x :: domains)

let pp_trace = Fmt.using (fun { local; domain; _} -> local, domain) pp_trace

let pp_received ppf = function
  | `Addr v -> Fmt.pf ppf "(`Addr %a)" (Fmt.hvbox pp_trace) v
  | `Domain v -> Fmt.pf ppf "(`Domain %a)" (Fmt.hvbox Mailbox.pp_domain) v
  | `Word v -> Fmt.pf ppf "(`Word %a)" (Fmt.hvbox Mailbox.pp_word) v

let pp_received ppf = function
  | received, Some date ->
    Fmt.pf ppf "{ @[<hov>received = %a;@ date = %a;@] }"
      Fmt.(Dump.list pp_received) received
      Date.pp date
  | received, None ->
    Fmt.pf ppf "{ @[<hov>received = %a;@] }"
      Fmt.(Dump.list pp_received) received

let pp ppf = function
  | { trace= Some trace; received; _ } ->
    Fmt.pf ppf "{ @[<hov>trace = %a;@ received = %a;@] }"
      pp_trace trace
      Fmt.(vbox (list ~sep:(always "@\n&@ ") pp_received)) received
  | { received; _ } ->
    Fmt.pf ppf "{ @[<hov>received = %a;@] }"
      Fmt.(vbox (list ~sep:(always "@\n&@ ") pp_received)) received

let get f t =
  if Field.(equal (v "Received") f)
  then List.map (fun x -> Value.Received x) t.received
  else if Field.(equal (v "Return-Path") f)
  then Option.(value ~default:[] (map (fun x -> [ Value.ReturnPath x ]) t.trace))
  else raise Not_found (* XXX(dinosaure): or [Invalid_argument _]? *)

let fold : (Number.t * ([> field ] as 'a) * Location.t) list -> t list -> (t list * (Number.t * 'a * Location.t) list) = fun fields t ->
  List.fold_left
    (fun (t, rest) -> function
       | index, `Trace (trace, received), location -> { index; trace; received; location; } :: t, rest
       | index, field, location -> t, (index, field, location) :: rest)
    (t, []) fields
  |> fun (t, fields) -> t, List.rev fields

module Encoder = struct
  open Encoder

  external id : 'a -> 'a = "%identity"

  let field = Field.Encoder.field
  let word = Mailbox.Encoder.word
  let domain = Mailbox.Encoder.domain
  let mailbox = Mailbox.Encoder.mailbox
  let date = Date.Encoder.date

  let return_path ppf m =
    keval ppf id [ !!field; char $ ':'; space; hov 1; !!mailbox; close; string $ "\r\n" ]
      (Field.v "Return-Path") m

  let received ppf = function
    | `Addr x -> mailbox ppf x
    | `Domain x -> domain ppf x
    | `Word x -> word ppf x

  let received ppf (l, d) =
    let sep = (fun ppf () -> keval ppf id [ space ]), () in
    let date ppf x = keval ppf id [ char $ ';'; space; !!date ] x in
    keval ppf id [ field $ (Field.v "Received"); char $ ':'; space; hov 1; !!(list ~sep received); !!(option date); close; string $ "\r\n" ] l d

  let trace ppf = function
    | { trace= Some r; received= rs; _ } -> keval ppf id [ !!return_path; !!(list received) ] r rs
    | { trace= None; received= rs; _ } -> (list received) ppf rs
end
