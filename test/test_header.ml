open Mrmime

let content_type = Alcotest.testable Content_type.pp Content_type.equal

let test_valued_header =
  Alcotest.test_case "valued header" `Quick @@ fun () ->
  let content_type_0 = Content_type.default in
  let content_type_1 =
    Content_type.(make `Text (Subtype.v `Text "richtext") Parameters.empty)
  in
  let v = Header.empty in
  let v =
    Header.add Field_name.content_type Field.(Content, content_type_0) v
  in
  let v =
    Header.add Field_name.content_type Field.(Content, content_type_1) v
  in
  (* XXX(dinosaure): prepend order. *)
  match Header.assoc Field_name.content_type v with
  | [ Field (_, Content, v1); Field (_, Content, v0) ] ->
      Alcotest.(check content_type) "v0" v0 content_type_0;
      Alcotest.(check content_type) "v1" v1 content_type_1
  | _ -> Alcotest.fail "Invalid header"

let default_content_type =
  Alcotest.test_case "default content type" `Quick @@ fun () ->
  let v = Header.empty in
  match (Header.assoc Field_name.content_type v, Header.content_type v) with
  | [], v0 -> Alcotest.(check content_type) "value" v0 Content_type.default
  | _ -> Alcotest.fail "Invalid header"

let () =
  Alcotest.run "header"
    [
      ("simple", [ test_valued_header ]);
      ("content-type", [ default_content_type ]);
    ]
