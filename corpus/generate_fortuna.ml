module Generate = Fuzz.Make (Fortuna)

let parsers =
  let open Mrmime in
  let unstructured = Field.(Witness Unstructured) in
  let open Field_name in
  Map.empty
  |> Map.add date unstructured
  |> Map.add from unstructured
  |> Map.add sender unstructured
  |> Map.add reply_to unstructured
  |> Map.add (v "To") unstructured
  |> Map.add cc unstructured
  |> Map.add bcc unstructured
  |> Map.add subject unstructured
  |> Map.add message_id unstructured
  |> Map.add comments unstructured
  |> Map.add content_type unstructured
  |> Map.add content_encoding unstructured

let rec decode_string str decoder =
  let open Mrmime in
  match Hd.decode decoder with
  | `End _ -> `Ok 0
  | `Field _v -> decode_string str decoder
  | `Malformed _err -> `Error (false, "Invalid generated email.")
  | `Await ->
      Hd.src decoder str 0 (String.length str);
      decode_string str decoder

let generate seed dst =
  let g = Mirage_crypto_rng.Fortuna.create () in
  Mirage_crypto_rng.Fortuna.reseed ~g (Cstruct.of_string seed);
  assert (Mirage_crypto_rng.Fortuna.seeded ~g);
  let hdr = Generate.header g in
  let str = Prettym.to_string Mrmime.Header.Encoder.header hdr in
  let decoder = Mrmime.Hd.decoder parsers in
  let ret = decode_string (str ^ "\r\n") decoder in
  let oc, oc_close =
    match dst with
    | `Standard -> (stdout, ignore)
    | `Filename filename ->
        let oc = open_out (Fpath.to_string filename) in
        (oc, close_out)
  in
  output_string oc str;
  oc_close oc;
  ret
