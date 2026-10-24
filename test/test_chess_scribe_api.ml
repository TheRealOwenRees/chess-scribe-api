let parse = Chess_scribe_api.Request.parse

let contains haystack needle =
  let n = String.length needle and h = String.length haystack in
  let rec go i =
    i + n <= h && (String.sub haystack i n = needle || go (i + 1))
  in
  n = 0 || go 0

let () =
  let parsed = parse {|{"pgn":"1. e4 e5 *"}|} in
  assert (parsed.pgn = "1. e4 e5 *");
  assert (parsed.clock = false);

  let parsed = parse {|{"pgn":"1. e4 *","diagramClock":true}|} in
  assert (parsed.clock = true);

  let parsed = parse {|{"pgn":"1. e4 *","diagrams":null}|} in
  assert (parsed.clock = false);

  let parsed =
    parse
      {|{"pgn":"1. e4 *","diagrams":[{"fen":"8/8/8/8/8/8/8/8 w - - 0 1","ply":1}]}|}
  in
  assert (parsed.clock = false);

  (* Omitting the required pgn must raise so the handler returns 400. *)
  let missing_pgn_raises =
    try
      ignore (parse {|{"diagrams":[]}|});
      false
    with Yojson.Safe.Util.Type_error _ | Yojson.Json_error _ -> true
  in
  assert missing_pgn_raises;

  (* End-to-end: clock times render next to a diagram when requested. *)
  let parsed =
    parse
      {|{"pgn":"1. e4 {[%clk 0:05:00]} e5 2. Nf3 *","diagramClock":true,"diagrams":[{"fen":"rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 0 2","ply":2}]}|}
  in
  let with_clock =
    Pgn_to_tex.to_tex ~diagram_data:parsed.diagrams ~clock:true parsed.pgn
  in
  let without_clock =
    Pgn_to_tex.to_tex ~diagram_data:parsed.diagrams ~clock:false parsed.pgn
  in
  assert (contains with_clock "0:05:00");
  assert (with_clock <> without_clock);

  print_endline "All request parsing tests passed"
