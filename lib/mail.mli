(*
 * Copyright (c) 2018-2019 Romain Calascibetta <romain.calascibetta@gmail.com>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *)

type 'a elt = { header : Header.t; body : 'a }

type 'a t =
  | Leaf of 'a elt
  | Multipart of 'a t option list elt
  | Message of 'a t elt
      (** Describe the structure of a mail as a tree:

 - Leaf: basic content of a mail. Text, image or any other discrete
   content type;

 - Multipart: mail with multiple bodies (one body for each
   content-type. text/html and text/plain for example).

 - Message: because an email can contain another email *)

val heavy_octet : string option -> Header.t -> string Angstrom.t
(** {i Heavy} parser of a body - it will stores bodies into [string]. *)

val light_octet :
  emitter:(string option -> unit) ->
  string option ->
  Header.t ->
  unit Angstrom.t
(** {i Light} parser of body - it sends contents to given [emitter]. *)

val mail : (Header.t * string t) Angstrom.t
(** Angstrom parser of an entire RFC 5322 mail (including header). *)

type 'id emitters = Header.t -> (string option -> unit) * 'id

val stream :
  emitters:(Header.t -> (string option -> unit) * 'id) ->
  (Header.t * 'id t) Angstrom.t
(** [stream ~emitters] is an Angstrom parser of an entire RFC 5322 mail which
   will use given emitters by [emitters] to store bodies. *)
