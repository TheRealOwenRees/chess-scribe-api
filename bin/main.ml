let () =
  Dream.run ~interface:"0.0.0.0" ~port:8080
  @@ Dream.logger
  @@ Dream.router
       [
         Dream.get "/" (fun request ->
             Dream.from_filesystem "static" "doc.html" request);
         (* Health check (Exact match) *)
         Dream.get "/health" (fun _ -> Dream.respond "OK");
         (* Specific API Endpoints (Must be ABOVE the wildcard) *)
         Dream.get "/api/v1/pdf" (fun _ -> Dream.html "Generate PDF");
         (* Exact match for the docs root *)
         Dream.get "/api/v1" (fun request ->
             Dream.from_filesystem "static" "doc.html" request);
         (* Dedicated route for swagger.json if accessed outside /api/ *)
         Dream.get "/swagger.json" (fun request ->
             Dream.from_filesystem "static" "swagger.json" request);
       ]
