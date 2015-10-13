(**
 * Copyright (c) 2014, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the "flow" directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 *
 *)

(***********************************************************************)
(* flow single (run analysis single-threaded) command *)
(***********************************************************************)

open CommandUtils

let spec = {
  CommandSpec.
  name = "single";
  doc = "Does a single-threaded check (testing)";
  usage = Printf.sprintf "Usage: %s single ROOT\n" CommandUtils.exe_name;
  args = CommandSpec.ArgSpec.(
    empty
    |> flag "--all" no_arg
        ~doc:"Typecheck all files, not just @flow"
    |> flag "--weak" no_arg
        ~doc:"Typecheck with weak inference, assuming dynamic types by default"
    |> flag "--debug" no_arg
        ~doc:"Print debug info during typecheck"
    |> flag "--verbose" no_arg
        ~doc:"Print verbose info during typecheck"
    |> flag "--verbose-indent" no_arg
        ~doc:"Indent verbose info during typecheck (implies --verbose)"
    |> flag "--json" no_arg
        ~doc:"Output errors in JSON format"
    |> flag "--profile" no_arg
        ~doc:"Output profiling information"
    |> flag "--quiet" no_arg
        ~doc:"Suppress info messages to stdout (included in --json)"
    |> flag "--module" (optional string)
        ~doc:"Specify a module system"
    |> flag "--lib" (optional string)
        ~doc:"Specify a library path"
    |> flag "--no-flowlib" no_arg
        ~doc:"Do not include embedded declarations"
    |> flag "--munge-underscore-members" no_arg
        ~doc:"Treat any class member name with a leading underscore as private"
    |> error_flags
    |> temp_dir_flag
    |> from_flag
    |> anon "root" (required string)
        ~doc:"Root"
  )
}

let main all weak debug verbose verbose_indent json profile quiet module_
         lib no_flowlib munge_underscore_members error_flags temp_dir from root
         () =
  FlowEventLogger.set_from from;
  let opt_libs = match lib with
  | None -> []
  | Some lib -> [Path.make lib]
  in

  let module_ = match module_ with
  | Some "node" -> "node"
  | Some "haste" -> "haste"
  | Some _ -> failwith "Invalid --module. Expected node or haste"
  | None -> "node"
  in

  let config_root = CommandUtils.guess_root (Some(root)) in
  let flowconfig = FlowConfig.get config_root in

  let munge_underscores = munge_underscore_members ||
      FlowConfig.(flowconfig.options.Opts.munge_underscores) in

  let opt_temp_dir = match temp_dir with
  | Some x -> x
  | None -> Path.to_string (FlowConfig.(flowconfig.options.Opts.temp_dir))
  in

  let opt_verbose =
    if verbose || verbose_indent
    then Some (if verbose_indent then 2 else 0)
    else None
  in

  let root_path = Path.make root in

  let options = {
    Options.opt_error_flags = error_flags;
    Options.opt_root = root_path;
    Options.opt_should_detach = false;
    Options.opt_check_mode = false;
    Options.opt_log_file = FlowConfig.(
      log_file ~tmp_dir:opt_temp_dir root_path flowconfig.options
    );
    Options.opt_all = all;
    Options.opt_weak = weak;
    Options.opt_debug = debug;
    Options.opt_verbose;
    Options.opt_traces = 0;
    Options.opt_json = json;
    Options.opt_quiet = quiet || json;
    Options.opt_profile = profile;
    Options.opt_strip_root = false;
    Options.opt_module = module_;
    Options.opt_module_name_mappers = FlowConfig.(
      flowconfig.options.Opts.module_name_mappers
    );
    Options.opt_libs;
    Options.opt_no_flowlib = no_flowlib;
    Options.opt_munge_underscores = munge_underscores;
    Options.opt_temp_dir;
    Options.opt_max_workers = 0;
  } in

  if ! Sys.interactive
  then ()
  else
    SharedMem.(init default_config);
    Types_js.single_main [root] options

let command = CommandSpec.command spec main
