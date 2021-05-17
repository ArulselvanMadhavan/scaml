
open Shexp_process
open Shexp_process.Infix
open Cmdliner

let command (exe: string) : bool t =
  find_executable exe >>| fun res -> res <> None

let scalafmt_install_link =
  "https://scalameta.org/scalafmt/docs/installation.html#install"

let install_scalafmt_suggestion : unit t =
  echo [%string "Install scalafmt from here: %{scalafmt_install_link}"]

let git_status_cmd =
  run "git" ["status"; "-vv"]

let git_diff_cmd =
  run "git" ["diff"; "--name-only"]

let list_files_to_format project_home =
  let git_status = chdir project_home @@ git_diff_cmd in
  capture_unit [Std_io.Stdout] git_status

(* let () = List.iter ~f:(Printf.printf "%s ") [""] *)

let run_scalafmt project_home =
  let open Shexp_process.Let_syntax in
  let%bind _ = echo "Running scalafmt" in
  let%bind files_to_format = list_files_to_format project_home in
  let files_list = Re.Str.split (Re.Str.regexp "\n") files_to_format in
  let files_with_path = Base.List.map files_list ~f:(fun x -> [%string "%{project_home}/%{x}"]) in
  let conf_path = [%string "%{project_home}/.scalafmt.conf"] in
  let metals_path = [%string "%{project_home}/.metals"] in
  let _ = Printf.printf "files_to_format %s\n" files_to_format in
  run "scalafmt" ["--config"; conf_path; "--exclude"; metals_path; String.concat " " files_with_path]

let git_root =
  let cmd = run "git" ["rev-parse"; "--show-toplevel"] in
  capture_unit [Std_io.Stdout] cmd

let main (project_home : string): unit t =
  command "scalafmt" >>= function
  | true ->
     echo "Found scalafmt" >> run_scalafmt project_home
  | false ->
     echo "Scalafmt not found. Install(Y/n)"

let project_path =
  let open Cmdliner in
  let doc = "Path to the project" in
  let git_home = eval git_root in
  Arg.(value & pos 0 string git_home & info [] ~docv:"PROJECT_PATH" ~doc)

let format project =
  let _ = Printf.printf "ProjectHome %s\n" project in
  eval (main project)

let info =
  let doc = "Run scalafmt on staged and unstages files" in
  let man = [
      `S Manpage.s_bugs;
      `P "Bug Reports Contact:github.com/ArulselvanMadhavan"
    ] in
  Term.info "formatter" ~version:"%%VERSION%%" ~doc ~exits:Term.default_exits ~man

let format_t = Term.(const format $ project_path)  

let () =
  Term.exit @@ Term.eval (format_t, info)
