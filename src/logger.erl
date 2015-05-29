
-module(logger).

-include("logger.hrl").
%% API
-export([start/0, get/1, set/2, set/3, reopen_log/0]).

-type loglevel() :: 0 | 1 | 2 | 3 | 4 | 5.

-spec start() -> ok.
-spec reopen_log() -> ok.
-spec set(module(),loglevel() | {loglevel(), list()}) -> {module, module()}.
-spec set(module(),string(),loglevel()) -> {module, module()}.
%%%===================================================================
%%% API
%%%===================================================================


%% %% Whether to write a crash log, and where. Undefined means no crash logger.
%% {crash_log, "../log/crash.log"},
%% %% Maximum size in bytes of events in the crash log - defaults to 65536
%% {crash_log_msg_size, 65536},
%% %% Maximum size of the crash log in bytes, before its rotated, set
%% %% to 0 to disable rotation - default is 0
%% {crash_log_size, 10485760},
%% %% What time to rotate the crash log - default is no time
%% %% rotation. See the README for a description of this format.
%% {crash_log_date, "$D0"},
%% %% Number of rotated crash logs to keep, 0 means keep only the
%% %% current one - default is 0
%% {crash_log_count, 5},
%% %% Whether to redirect error_logger messages into lager - defaults to true
%% {error_logger_redirect, true},
%% %% How many messages per second to allow from error_logger before we start dropping them
%% {error_logger_hwm, 50},
%% %% How big the gen_event mailbox can get before it is switched into sync mode
%% {async_threshold, 20},
%% %% Switch back to async mode, when gen_event mailbox size decrease from `async_threshold'
%% %% to async_threshold - async_threshold_window
%% {async_threshold_window, 5}
%% log_root variable is optional, by default file paths are relative to CWD.	 
%% {log_root, "/var/log/"}
%% handlers
%% {handlers, [
%%     {lager_console_backend, info},
%%     {lager_file_backend, [{file, "error.log"}, {level, error}]},
%%     {lager_file_backend, [{file, "console.log"}, {level, info}]}
%% ]}
%% 

start() ->
    application:load(sasl),
    application:set_env(sasl, sasl_error_logger, false),
    application:load(lager),
	
	LogRoot = env:get2(lagger_logger, log_root, "../log/"),
    LogRotateDate = env:get2(lagger_logger, log_rotate_date, "$D0"),
    LogRotateSize = env:get2(lagger_logger, log_rotate_size, 10*1024*1024),
    LogRotateCount = env:get2(lagger_logger, log_rotate_count, 31), 
    LogRateLimit = env:get2(lagger_logger, log_rate_limit, 100), 
	Threshold = env:get2(lagger_logger, async_threshold, 20), 
	ThresholdWindow = env:get2(lagger_logger, async_threshold_window, 5),
	ConsoleLog = LogRoot++atom_to_list(node_util:get_node_sname(node())) ++ "_node_console.log", 
	ErrorLog = LogRoot++atom_to_list(node_util:get_node_sname(node())) ++ "_node_error.log",
	CrashLog = LogRoot++atom_to_list(node_util:get_node_sname(node())) ++ "_node_crash.log",
	
    application:set_env(lager, error_logger_hwm, LogRateLimit),
    application:set_env(
      lager, handlers,
      [
%% 	   {lager_console_backend, info},
       {lager_file_backend, [{file, ConsoleLog}, {level, info}, {date, LogRotateDate},
                             {count, LogRotateCount}, {size, LogRotateSize}]},
       {lager_file_backend, [{file, ErrorLog}, {level, error}, {date, LogRotateDate},
                             {count, LogRotateCount}, {size, LogRotateSize}]}]),
	
    application:set_env(lager, crash_log, CrashLog),
    application:set_env(lager, crash_log_date, LogRotateDate),
    application:set_env(lager, crash_log_size, LogRotateSize),
    application:set_env(lager, crash_log_count, LogRotateCount),
	applcation:set_env(lager, async_threshold, Threshold),
	applcation:set_env(lager, async_threshold_window, ThresholdWindow),	
	lager:start(),
    ok.

get(Handle) ->
    case lager:get_loglevel(Handle) of
        none -> {0, no_log, "No log"};
        emergency -> {1, critical, "Critical"};
        alert -> {1, critical, "Critical"};
        critical -> {1, critical, "Critical"};
        error -> {2, error, "Error"};
        warning -> {3, warning, "Warning"};
        notice -> {3, warning, "Warning"};
        info -> {4, info, "Info"};
        debug -> {5, debug, "Debug"}
    end.

set(Handle,LogLevel) when is_integer(LogLevel) ->
    LagerLogLevel = case LogLevel of
                        0 -> none;
                        1 -> critical;
                        2 -> error;
                        3 -> warning;
                        4 -> info;
                        5 -> debug
                    end,
	lists:foreach(
              fun(H) when H == Handle ->
                      lager:set_loglevel(H, LagerLogLevel);
                 (_) ->
                      ok
              end, gen_event:which_handlers(lager_event)),
	 {module, lager}.

set(Handle,Ident,LogLevel) when is_integer(LogLevel) ->
    LagerLogLevel = case LogLevel of
                        0 -> none;
                        1 -> critical;
                        2 -> error;
                        3 -> warning;
                        4 -> info;
                        5 -> debug
                    end,
	lists:foreach(
              fun(H) when H == Handle ->
                      lager:set_loglevel(H, Ident, LagerLogLevel);
                 (_) ->
                      ok
              end, gen_event:which_handlers(lager_event)),
	{module, lager}.

reopen_log() ->
    lager_crash_log ! rotate,
    lists:foreach(
      fun({lager_file_backend, File}) ->
              whereis(lager_event) ! {rotate, File};
         (_) ->
              ok
      end, gen_event:which_handlers(lager_event)).
