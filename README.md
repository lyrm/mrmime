# Mr. MIME (Multipurpose Internet Mail Extensions)

`mrmime` is a library to parse and generate mail according to several RFCs:
- [RFC822][rfc822]: Standard For The Format of ARPA Internet Text Messages
- [RFC2822][rfc2822]: Internet Message Format
- [RFC5321][rfc5321]: Simple Mail Transfer Protocol
- [RFC5322][rfc5322]: Internet Message Format
- [RfC2045][rfc2045]: MIME Part One: Format of Internet Message Bodies
- [RFC2046][rfc2046]: MIME Part Two: Media Types
- [RFC2047][rfc2047]: MIME Part Three: Message-Header Extensions for Non-ASCII Text
- [RFC2049][rfc2049]: MIME Part Five: Conformance Criteria and Examples
- [RFC6532][rfc6532]: Internationalized Email Headers

To parse mails, `mrmime` uses [`angstrom`][angstrom] and does it best
according to rfc recommendations. It has be tested over more than 2
billions mails and is able to parse all of them. However,
results are not always what was expected due to ?.

`mrmime` also enables to generate valid mails from an OCaml
description. Generation abides by the following rules:
- produced streams emit lines one by one
- it does its best to limit lines to 78 characters
- generated mails follow [RFC6532][rfc6532] and use UTF-8 encoding

## How to parse a mail?

An mail can be parsed in two different ways depending on what parts of
the mail you are interesting in. To match constraints and
functionnalities we wanted, each parser has its own API.

### Parsing only the header part

For many purposes, it is only necessary to parse the header part of a
mail. These cases require the `Hd` sub-module.

Typical use cases include SMTP servers and usually need to have a low
memory consumption. That's why an _stream API_ is provided.

An complete example of a DKIM implementation using this `Hd`
sub-module is available on the [`ocaml-dkim`][ocaml-dkim] project. The
following code lines are extracted (and simplified) from it and shows
how the _stream API_ enables to implement a DKIM checker that only
needs one pass to verify a mail.


```ocaml
let dkim_signature = Mrmime.Field_name.v "DKIM-Signature"

let extract_dkim () =
  let open Mrmime in
  let tmp = Bytes.create 0x1000 in
  let buffer = Bigstringaf.create 0x1000 in
  let decoder = Hd.decoder buffer in
  let rec decode () = match Hd.decode decoder with
    | `Field field ->
      ( match Location.prj field with
      | Field.Field (field_name, Unstructured, v)
          when Field_name.equal field_name dkim_signature ->
        Fmt.pr "%a: %a\n%!" Field_name.pp dkim_signature Unstructured.pp v
      | _ -> decode () )
    | `Malformed err -> failwith err
    | `End rest -> ()
    | `Await ->
      let len = input stdin tmp 0 (Bytes.length tmp) in
      ( match Hd.src decoder (Bytes.unsafe_to_string tmp) 0 len with
        | Ok () -> decode ()
        | Error (`Msg err) -> failwith err ) in
  decode ()
```

This little snippet parses a mail **which is encoded with CRLF end-of-line**
from `stdin` (so you should map your mail with this newline convention). When it
reachs a `DKIM` field, it prints a _well-parsed_ value of it (in our case, an
_unstructured_ value). [`Other`] corresponds to other fields - `DKIM` signature
can appear here where we failed to parse value as an _unstructured_ value.

### Parsing a mail entirely

For some cases, it may be necessary to also extract the bodies of a
mail and parse the entire mail. This is the initial goal of
`mrmime`. In this case, `Mail` is the appropriate sub-module and
provides an [`angstrom`][angstrom] non-stream parser.

Bodies can be weight and if you want to store them by yourself, we
provide an API which expects consumers to consume bodies (and store
them, for example, into UNIX files).

A _complex_ example is available on [`ptt`][ptt] to extract bodies and
save them into UNIX files. For this, we use the function `stream` to
parse the mail:

```ocaml
val stream : emitters:(Header.t -> (string option -> unit) * 'id) -> (Header.t * 'id t) Angstrom.t
```

which calls `emitters` for every parts of your mail. The parser then
decodes properly each of them accordingly to
`Content-Transfer-Encoding` and returns you inputs into your consumer.

## How to emit a mail?

`mrmime` is able to generate a mail from an OCaml description of it. There are
several ways to craft informations like address or `Content-Type` field for a
specific part.

Many sub-modules of `mrmime` provide a way to construct an information like a
subject needed for your mail or recipients of it. For example, the sub-module
`Mailbox` provides an easy way to construct an address:

```ocaml
let romain_calascibetta =
  let open Mrmime.Mailbox in
  Local.[ w "romain"; w "calascibetta" ] @ Domain.(domain, [ a "x25519"; a "net" ])
```

Documentation was done to help you to construct many of these values. Obviously,
`Header` is the module to construct headers:

```ocaml
let header =
  let open Mrmime in
  Field.[ Field (Field_name.subject, Unstructured,
                 Unstructured.Craft.(compile [ v "Simple"; sp 1; v "Email" ]))
        ; Field (Field_name.v "To", Addresses, [ `Mailbox romain_calascibetta ])
        ; Field (Field_name.date, Date, (Date.of_ptime ~zone:GMT (Ptime_clock.now ()))) ]
  |> Header.of_list
```

Then, `Header` provides a `to_stream` function which will emit your header line
per line (with the CRLF newline convention) - mostly to be able to branch it
into a SMTP pipe.

Finally, for a multipart mail, the `Mt` sub-module is the most interesting to
make part from stream (stream from a file or from standard input) associated to
`Content` fields (like `Content-Transfer-Encoding`). `mrmime` takes care about
how to encode your stream (`base64` or `quoted-printable`).

A _complex_ example of how to use `Mt` module is available in
[`facteur`][facteur] project which is able to send a multipart mail.

## Encoding

A real effort was made to consider any inputs/outputs of `mrmime` as UTF-8
string. This result is done by some underlying packages:
- [rosetta][rosetta] as universal unifier to unicode
- [uuuu][uuuu] as mapper from ISO-8859 to Unicode
- [coin][coin] as mapper from KOI8-{U,R} to Unicode
- [yuscii][yuscii] as mapper from UTF-7 to Unicode

SMTP protocol constraints bodies to use only 7 bits per byte (historial
limitation). By this way, encoding such as _quoted-printable_ or _base64_ are
used to encode bodies and respect this limitation. `mrmime` uses:
- [pecu][pecu] as a stream encoder/decoder
- [base64][base64] (`base64.rfc2045` sub-package) as a stream encoder/decoder

## Status of the project

`mrmime` is really experimental. Where it wants to take care about many purposes
(_encoding_ or _multipart_), API should change often. We reach a first version
because we are able to send a well formed multipart mail from it - however, it's
possible to reach weird case where `mrmime` can emit invalid mail.

About parser, the same advise is done where Mail format is not really respected
by implementations in many cases and the parser should fail on some of them for
a weird reason.

Of course, feedback is expected to improve it. So you can use it, but you should
not expect an industrial quality - I mean, not yet. So play with it, and enjoy
your hacking!

[rfc822]: https://tools.ietf.org/html/rfc822
[rfc2822]: https://tools.ietf.org/html/rfc2822
[rfc5321]: https://tools.ietf.org/html/rfc5321
[rfc5322]: https://tools.ietf.org/html/rfc5322
[rfc2045]: https://tools.ietf.org/html/rfc2045
[rfc2046]: https://tools.ietf.org/html/rfc2046
[rfc2047]: https://tools.ietf.org/html/rfc2047
[rfc2049]: https://tools.ietf.org/html/rfc2049
[rfc6532]: https://tools.ietf.org/html/rfc6532
[ocaml-dkim]: https://github.com/dinosaure/ocaml-dkim.git
[ptt]: https://github.com/dinosaure/ptt.git
[facteur]: https://github.com/dinosaure/facteur.git
[angstrom]: https://github.com/inhabitedtype/angstrom.git
[rosetta]: https://github.com/mirage/rosetta.git
[uuuu]: https://github.com/mirage/uuuu.git
[coin]: https://github.com/mirage/coin.git
[yuscii]: https://github.com/mirage/yuscii.git
[pecu]: https://github.com/mirage/pecu.git
[base64]: https://github.com/mirage/ocaml-base64.git
