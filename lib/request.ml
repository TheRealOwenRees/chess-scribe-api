open Yojson.Safe.Util

type parsed = { pgn : string; clock : bool; diagrams : Pgn_to_tex.diagram_data }

let parse body =
  let json = Yojson.Safe.from_string body in
  let pgn = json |> member "pgn" |> to_string in
  let clock =
    json |> member "diagramClock" |> to_bool_option
    |> Option.value ~default:false
  in
  let diagrams =
    match json |> member "diagrams" with
    | `Null -> Pgn_to_tex.empty_diagrams
    | diagrams_json ->
        Yojson.Safe.to_string diagrams_json |> Pgn_to_tex.parse_diagrams_json
  in
  { pgn; clock; diagrams }
