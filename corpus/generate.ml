
let generate seed fuzzer dst  =
  match fuzzer with
  | `Fortuna -> Generate_fortuna.generate seed dst
  | `Crowbar -> Generate_crowbar.generate dst

open Cmdliner

let base64 =
  Arg.conv
    ((fun str -> Base64.decode str), Fmt.using Base64.encode_string Fmt.string)

let filename =
  let parser = function
    | "-" -> Ok `Standard
    | str -> Rresult.(Fpath.of_string str >>| fun v -> `Filename v)
  in
  let pp ppf = function
    | `Standard -> Fmt.string ppf "-"
    | `Filename v -> Fpath.pp ppf v
  in
  Arg.conv (parser, pp)

let fuzzer =
  let available = [ ("fortuna", `Fortuna); ("crowbar", `Crowbar) ] in
  let kind = String.concat " or " (List.map (fun (n, _) -> n) available) in
  let kind_of_string str = List.assoc_opt str available in
  let pars = Arg.parser_of_kind_of_string ~kind kind_of_string in
  let printer fmt v =
    let str = fst (List.find (fun (_, v') -> v = v') available) in
    Format.fprintf fmt "%s" str
  in
  let doc = "Fuzzer uses to randomly generate values. Value can be fortuna \
             (default value) or crowbar. " in
  let fuzzer_conv = Arg.conv ~docv:"FUZZER" (pars, printer) in
  Arg.(value
       & opt fuzzer_conv `Fortuna
       & info [ "f"; "fuzzer" ] ~doc)

let seed =
  let doc = "Fortuna seed. Has no use if fuzzer value is set to [crowbar]." in
  Arg.(required & opt (some base64) None & info [ "s"; "seed" ] ~doc)

let output = Arg.(value & pos ~rev:true 0 filename `Standard & info [])

let cmd =
  let doc = "Generate a valid email from a seed." in
  let man =
    [
      `S "DESCRIPTION";
      `P
        "Generate a random email from the $(i,fortuna) random number generator \
         and the $(i,base64) given seed.";
    ]
  in
  (Term.(ret (const generate $ seed $ fuzzer $ output )), Term.info "generate" ~doc ~man)

let () = Term.(exit_status @@ eval cmd)
