type t = [`Group of Group.t | `Mailbox of Mailbox.t]

val group : Group.t -> t
val mailbox : Mailbox.t -> t

val pp : t Fmt.t

module Encoder : sig
  val address : t Encoder.encoding
  val addresses : t list Encoder.encoding
end
