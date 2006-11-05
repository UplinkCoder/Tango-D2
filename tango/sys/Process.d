/*
 * Copyright (c) 2005 Regan Heath
 * Copyright (c) 2006 Juan Jose Comellas <juanjo@comellas.com.ar>
 *
 * Permission to use, copy, modify, distribute and sell this software
 * and its documentation for any purpose is hereby granted without fee,
 * provided that the above copyright notice appear in all copies and
 * that both that copyright notice and this permission notice appear
 * in supporting documentation.  Author makes no representations about
 * the suitability of this software for any purpose. It is provided
 * "as is" without express or implied warranty.
 */

module tango.sys.Process;

private import tango.io.FileConst;
private import tango.io.Stdout;
private import tango.sys.Common;
private import tango.sys.Pipe;
private import tango.text.convert.Format;
private import tango.text.SimpleIterator;
private import tango.text.Text;

private import tango.stdc.stdlib;
private import tango.stdc.string;

version (Windows)
{
    private import tango.sys.windows.winbase;
}
else version (Posix)
{
    private import tango.stdc.errno;
    private import tango.stdc.posix.fcntl;
    private import tango.stdc.posix.unistd;
    private import tango.stdc.posix.sys.wait;
}


/**
 * The $D_CODE(Process) class is used to start external programs and
 * communicate with them via their standard input, output and error
 * streams.
 *
 * You can pass either the command line or an array of arguments to execute,
 * either in the constructor or to the $D_CODE(args) property. The environment
 * variables can be set in a similar way using the $D_CODE(env) property and
 * you can set the program's working directory via the $D_CODE(workDir)
 * property.
 *
 * To actually start a process you need to use the $D_CODE(execute()) method.
 * Once the program is running you will be able to write to its standard input
 * via the $D_CODE(stdin) $D_CODE(PipeConduit) and you will be able to read
 * from its standard output and error through the $D_CODE(stdout) and
 * $D_CODE(stderr) $D_CODE(PipeConduit)'s respectively.
 *
 * You can check whether the process is running or not with the
 * $D_CODE(isRunning()) method and you can get its process ID via the $(pid)
 * property.
 *
 * After you are done with the process of if you just want to wait for it to
 * end you need to call the $D_CODE(wait()) method, which will return once the
 * process is no longer running.
 *
 * To stop a running process you must use the $D_CODE(kill()) method. If you do
 * this you cannot call the $D_CODE(wait()) method. Once the $D_CODE(kill())
 * method returns the process will be already dead.
 *
 * Examples:
 * ---
 * try
 * {
 *     uint i = 0;
 *
 *     auto p = new Process("ls -al");
 *
 *     p.execute();
 *
 *     Stdout.formatln("Output from {0}:", p.programName);
 *
 *     foreach (line; new LineIterator(p.stdout))
 *     {
 *         Stdout.formatln("line {0}: '{1}'", i++, line);
 *     }
 *
 *     auto result = p.wait();
 *
 *     Stdout.formatln("Process '{0}' ({1}) exited with reason {2}, status {3}",
 *                     p.programName, p.pid, cast(int) result.reason, result.status);
 * }
 * catch (ProcessException e)
 * {
 *     Stdout.formatln("Process execution failed: {0}", e.toUtf8());
 * }
 * ---
 */
class Process
{
    /**
     * Result returned by wait().
     */
    public struct Result
    {
        /**
         * Reason returned by wait() indicating why the process is no
         * longer running.
         */
        public enum Reason: short
        {
            Exit,
            Signal,
            Stop,
            Continue,
            Error
        }

        Reason  reason;
        int     status;
    }

    static const uint DefaultStdinBufferSize    = 512;
    static const uint DefaultStdoutBufferSize   = 8192;
    static const uint DefaultStderrBufferSize   = 512;

    private char[][]    _args;
    private char[][]    _env;
    private char[]      _workDir;
    private PipeConduit _stdin;
    private PipeConduit _stdout;
    private PipeConduit _stderr;
    private bool        _running = false;

    version (Windows)
    {
        private PROCESS_INFORMATION *_info = null;
    }
    else
    {
        private pid_t _pid = cast(pid_t) -1;
    }

    /**
     * Constructor.
     *
     * Params:
     * command  = string with the process' command line; arguments that have
     *            embedded whitespace must be enclosed in inside double-quotes (").
     * env      = array of strings with the process' environment variables;
     *            each element must follow the following format:
     *            <NAME>=<VALUE>
     *
     * Examples:
     * ---
     * char[]   command = "myprogram \"first argument\" second third";
     * char[][] env;
     *
     * // Environment variables
     * env ~= "MYVAR1=first";
     * env ~= "MYVAR2=second";
     *
     * auto p = new Process(command, env)
     * ---
     */
    public this(char[] command, char[][] env = null)
    in
    {
        assert(command.length > 0);
    }
    body
    {
        _args = splitArgs(command);
        _env = env;
    }

    /**
     * Constructor.
     *
     * Params:
     * args     = array of strings with the process' arguments; the first
     *            argument must be the process' name.
     * env      = array of strings with the process' environment variables;
     *            each element must follow the following format:
     *            <NAME>=<VALUE>
     *
     * Examples:
     * ---
     * char[][] args;
     * char[][] env;
     *
     * // Process name
     * args ~= "myprogram";
     * // Process arguments
     * args ~= "first argument";
     * args ~= "second";
     * args ~= "third";
     *
     * // Environment variables
     * env ~= "MYVAR1=first";
     * env ~= "MYVAR2=second";
     *
     * auto p = new Process(args, env)
     * ---
     */
    public this(char[][] args, char[][] env = null)
    in
    {
        assert(args.length > 0);
        assert(args[0].length > 0);
    }
    body
    {
        _args = args;
        _env = env;
    }

    /**
     * Destructor
     */
    public ~this()
    {
        clean();
    }

    /**
     * Indicate whether the process is running or not.
     */
    public bool isRunning()
    {
        return _running;
    }

    /**
     * Return the running process' ID.
     *
     * Returns: an int with the process ID if the process is running;
     *          -1 if not.
     */
    public int pid()
    {
        version (Windows)
        {
            return (_info !is null ? cast(int) _info.dwProcessId : -1);
        }
        else // version (Posix)
        {
            return cast(int) _pid;
        }
    }

    /**
     * Return the process' executable filename.
     */
    public char[] programName()
    {
        return (_args !is null ? _args[0] : null);
    }

    /**
     * Set the process' executable filename.
     */
    public void programName(char[] name)
    {
        if (_args.length == 0)
        {
            _args.length = 1;
        }
        _args[0] = name;
    }

    /**
     * Return an array with the process' arguments.
     */
    public char[][] args()
    {
        return _args;
    }

    /**
     * Set the process' arguments from an array of arguments.
     *
     * Remarks:
     * The first element of the array must be the name of the process'
     * executable.
     */
    public void args(char[][] args)
    {
        _args = args;
    }

    /**
     * Set the process' arguments from a command line.
     *
     * Params:
     * command  = command line of the process to be executed; each argument
     *            must be separated by a space and arguments that contain
     *            spaces must be enclosed in double quotes; the first element
     *            of the array must be the name of the process' executable.
     *
     * Examples:
     * ---
     * p.args("myprogram first \"second argument\" third");
     * ---
     */
    public void args(char[] command)
    in
    {
        assert(command.length > 0);
    }
    body
    {
        _args = splitArgs(command);
    }

    /**
     * Return an array with the process' environment variables.
     */
    public char[][] env()
    {
        return _env;
    }

    /**
     * Set the process' environment variables from an array of string.
     *
     * Params:
     * env  = array of string containing the environment variables for the
     *        process. Each string must include the name and the value of each
     *        variable in the following format: <name>=<value>.
     *
     * Examples:
     * ---
     * char[][] vars;
     *
     * vars ~= "VAR1=VALUE1";
     * vars ~= "VAR2=VALUE2";
     *
     * p.env = vars;
     * ---
     */
    public void env(char[][] env)
    {
        _env = env;
    }

    /**
     * Return an UTF-8 string with the process' command line.
     */
    public char[] toUtf8()
    {
        char[] command;

        for (uint i = 0; i < _args.length; ++i)
        {
            if (i > 0)
            {
                command ~= ' ';
            }
            if (find(_args[i], ' ') || _args[i].length == 0)
            {
                command ~= '"';
                command ~= _args[i];
                command ~= '"';
            }
            else
            {
                command ~= _args[i];
            }
        }
        return command;
    }

    /**
     * Return the working directory for the process.
     *
     * Returns: a string with the working directory; null if the working
     *          directory is the current directory.
     */
    public char[] workDir()
    {
        return _workDir;
    }

    /**
     * Set the working directory for the process.
     *
     * Params:
     * dir  = a string with the working directory; null if the working
     *         directory is the current directory.
     */
    public void workDir(char[] dir)
    {
        _workDir = dir;
    }

    /**
     * Return the running process' standard input pipe.
     *
     * Returns: a write-only $D_CODE(PipeConduit) connected to the child
     *          process' stdin.
     *
     * Remarks:
     * The process must be running before calling this method.
     */
    public PipeConduit stdin()
    in
    {
        assert(_running);
    }
    body
    {
        return _stdin;
    }

    /**
     * Return the running process' standard output pipe.
     *
     * Returns: a read-only $D_CODE(PipeConduit) connected to the child
     *          process' stdout.
     *
     * Remarks:
     * The process must be running before calling this method.
     */
    public PipeConduit stdout()
    in
    {
        assert(_running);
    }
    body
    {
        return _stdout;
    }

    /**
     * Return the running process' standard error pipe.
     *
     * Returns: a read-only $D_CODE(PipeConduit) connected to the child
     *          process' stderr.
     *
     * Remarks:
     * The process must be running before calling this method.
     */
    public PipeConduit stderr()
    in
    {
        assert(_running);
    }
    body
    {
        return _stdin;
    }

    /**
     * Execute a process using the arguments that were supplied to the
     * constructor or to the $D_CODE(args) property.
     *
     * Once the process is executed successfully, its input and output can be
     * manipulated through the $D_CODE(stdin), $D_CODE(stdout) and
     * $D_CODE(stderr) member $D_CODE(PipeConduit)'s.
     *
     * Throws:
     * $D_CODE(ProcessCreateException) if the process could not be created
     * successfully; $D_CODE(ProcessForkException) if the call to the fork()
     * system call failed (on POSIX-compatible platforms).
     *
     * Remarks:
     * The process must not be running and the list of arguments must
     * not be empty before calling this method.
     */
    public void execute()
    in
    {
        assert(!_running);
        assert(_args !is null && _args[0] !is null);
    }
    body
    {
        version (Windows)
        {
            STARTUPINFOA startup;
            char* envptr = null;

            Pipe pin = new Pipe(DefaultStdinBufferSize);
            Pipe pout = new Pipe(DefaultStdoutBufferSize);
            Pipe perr = new Pipe(DefaultStderrBufferSize);
            char[] command;

            GetStartupInfoA(&startup);

            // Replace stdin with the "read" pipe
            _stdin = pin.sink;
            startup.hStdInput = cast(HANDLE) _stdin.getHandle();
            pin.source.close();

            // Replace stdout with the "write" pipe
            _stdout = pout.source;
            startup.hStdOutput = cast(HANDLE) _stdout.getHandle();
            pout.sink.close();

            // Replace stderr with the "write" pipe
            _stderr = perr.source;
            startup.hStdError = cast(HANDLE) _stderr.getHandle();
            perr.sink.close();

            startup.dwFlags = STARTF_USESTDHANDLES;

            _info = new PROCESS_INFORMATION;

            command = toUtf8();
            command ~= '\0';
            // Convert the the environment variables to the format expected
            // by CreateProcess().
            envptr = toNullEndedBuffer(_env);

            // Convert the working directory to a null-ended string if
            // necessary.
            if (CreateProcessA(null, command.ptr, null, null, true,
                               DETACHED_PROCESS, envptr.ptr, toUtf8z(_workDir),
                               &startup, _info))
            {
                CloseHandle(_info.hThread);
                _running = true;
            }
            else
            {
                throw new ProcessCreateException(_args[0], __FILE__, __LINE__);
            }
        }
        else version (Posix)
        {
            Pipe pin = new Pipe(DefaultStdinBufferSize);
            Pipe pout = new Pipe(DefaultStdoutBufferSize);
            Pipe perr = new Pipe(DefaultStderrBufferSize);
            // This pipe is used to propagate the result of the call to
            // execv*() from the child process to the parent process.
            Pipe pexec = new Pipe(8);
            int status = 0;

            _pid = fork();
            if (_pid >= 0)
            {
                if (_pid != 0)
                {
                    // Parent process
                    _stdin = pin.sink;
                    pin.source.close();

                    _stdout = pout.source;
                    pout.sink.close();

                    _stderr = perr.source;
                    perr.sink.close();

                    pexec.sink.close();
                    scope(exit)
                        pexec.source.close();

                    try
                    {
                        pexec.source.read((cast(byte*) &status)[0 .. status.sizeof]);
                    }
                    catch (Exception e)
                    {
                        // Everything's OK, the pipe was closed after the call to execv*()
                    }

                    if (status == 0)
                    {
                        _running = true;
                    }
                    else
                    {
                        // We set errno to the value that was sent through
                        // the pipe from the child process
                        errno = status;
                        _running = false;

                        throw new ProcessCreateException(_args[0], __FILE__, __LINE__);
                    }
                }
                else
                {
                    // Child process
                    int rc;
                    char*[] argptr;
                    char*[] envptr;

                    // Replace stdin with the "read" pipe
                    dup2(pin.source.getHandle(), STDIN_FILENO);
                    pin.sink().close();
                    scope(exit)
                        pin.source.close();

                    // Replace stdout with the "write" pipe
                    dup2(pout.sink.getHandle(), STDOUT_FILENO);
                    pout.source.close();
                    scope(exit)
                        pout.sink.close();

                    // Replace stderr with the "write" pipe
                    dup2(perr.sink.getHandle(), STDERR_FILENO);
                    perr.source.close();
                    scope(exit)
                        perr.sink.close();

                    // We close the unneeded part of the execv*() notification pipe
                    pexec.source.close();
                    scope(exit)
                        pexec.sink.close();
                    // Set the "write" pipe so that it closes upon a successful
                    // call to execv*()
                    if (fcntl(cast(int) pexec.sink.getHandle(), F_SETFD, FD_CLOEXEC) == 0)
                    {
                        // Convert the arguments and the environment variables to
                        // the format expected by the execv() family of functions.
                        argptr = toNullEndedArray(_args);
                        envptr = toNullEndedArray(_env);

                        // Switch to the working directory if it has been set.
                        if (_workDir.length > 0)
                        {
                            chdir(toUtf8z(_workDir));
                        }

                        // Replace the child fork with a new process. We always use the
                        // system PATH to look for executables that don't specify
                        // directories in their names.
                        rc = execvpe(_args[0], argptr, envptr);
                        if (rc == -1)
                        {
                            Stdout.formatln("Failed to exec {0}: {1}",
                                            _args[0], lastSysErrorMsg());

                            try
                            {
                                status = errno;

                                // Propagate the child process' errno value to
                                // the parent process.
                                pexec.sink.write((cast(byte*) &status)[0 .. status.sizeof]);
                            }
                            catch (Exception e)
                            {
                            }
                            exit(errno);
                        }
                    }
                    else
                    {
                        Stdout.formatln("Failed to set notification pipe to close-on-exec for {0}: {1}",
                                        _args[0], lastSysErrorMsg());
                        exit(errno);
                    }
                }
            }
            else
            {
                throw new ProcessForkException(_pid, __FILE__, __LINE__);
            }
        }
        else
        {
            assert(false, "tango.sys.Process: Unsupported platform");
        }
    }


    /**
     * Unconditionally wait for a process to end and return the reason and
     * status code why the process ended.
     *
     * Returns:
     * The return value is a $D_CODE(Result) struct, which has two members:
     * $D_CODE(reason) and $D_CODE(status). The $D_CODE(reason) can take the
     * following values:
     *
     * Process.Result.Reason.Exit: the child process exited normally;
     *                             $D_CODE(status) has the process' return
     *                             code.
     *
     * Process.Result.Reason.Signal: the child process was killed by a signal;
     *                               $D_CODE(status) has the signal number
     *                               that killed the process.
     *
     * Process.Result.Reason.Stop: the process was stopped; $D_CODE(status)
     *                             has the signal number that was used to stop
     *                             the process.
     *
     * Process.Result.Reason.Continue: the process had been previously stopped
     *                                 and has now been restarted;
     *                                 $D_CODE(status) has the signal number
     *                                 that was used to continue the process.
     *
     * Process.Result.Reason.Error: We could not properly wait on the child
     *                              process; $D_CODE(status) has the
     *                              $D_CODE(errno) value if the process was
     *                              running and -1 if not.
     *
     * Remarks:
     * You can only call $D_CODE(wait()) on a running process once.
     * The $D_CODE(Signal), $D_CODE(Stop) and $D_CODE(Continue) reasons will
     * only be returned on POSIX-compatible platforms.
     */
    public Result wait()
    {
        version (Windows)
        {
            Result result;

            if (_running)
            {
                DWORD rc;
                DWORD exitCode;

                assert(_info !is null);

                rc = WaitForSingleObject(_info.hProcess, INFINITE);
                if (rc == WAIT_OBJECT_0)
                {
                    GetExitCodeProcess(_info.hProcess, &exitCode);

                    result.reason = Result.Reason.Exit;
                    result.status = cast(typeof(result.status)) exitCode;
                }
                else if (rc == WAIT_FAILED)
                {
                    result.reason = Result.Reason.Error;
                    result.status = cast(short) GetLastError();
                }
                clean();
            }
            else
            {
                result.reason = Result.Reason.Error;
                result.status = -1;
            }
            return result;
        }
        else version (Posix)
        {
            Result result;

            if (_running)
            {
                int rc;

                // Wait for child process to end.
                if (waitpid(_pid, &rc, 0) != -1)
                {
                    if (WIFEXITED(rc))
                    {
                        result.reason = Result.Reason.Exit;
                        result.status = WEXITSTATUS(rc);
                        if (result.status != 0)
                        {
                            debug (Process)
                                Stdout.formatln("Child process '{0}' ({1}) returned with code {2}\n",
                                                _args[0], _pid, result.status);
                        }
                    }
                    else
                    {
                        if (WIFSIGNALED(rc))
                        {
                            result.reason = Result.Reason.Signal;
                            result.status = WTERMSIG(rc);

                            debug (Process)
                                Stdout.formatln("Child process '{0}' ({1}) was killed prematurely "
                                                "with signal {2}",
                                                _args[0], _pid, result.status);
                        }
                        else if (WIFSTOPPED(rc))
                        {
                            result.reason = Result.Reason.Stop;
                            result.status = WSTOPSIG(rc);

                            debug (Process)
                                Stdout.formatln("Child process '{0}' ({1}) was stopped "
                                                "with signal {2}",
                                                _args[0], _pid, result.status);
                        }
                        else if (WIFCONTINUED(rc))
                        {
                            result.reason = Result.Reason.Stop;
                            result.status = WSTOPSIG(rc);

                            debug (Process)
                                Stdout.formatln("Child process '{0}' ({1}) was continued "
                                                "with signal {2}",
                                                _args[0], _pid, result.status);
                        }
                        else
                        {
                            result.reason = Result.Reason.Error;
                            result.status = rc;

                            debug (Process)
                                Stdout.formatln("Child process '{0}' ({1}) failed "
                                                "with unknown exit status {2}\n",
                                                _args[0], _pid, result.status);
                        }
                    }
                }
                else
                {
                    result.reason = Result.Reason.Error;
                    result.status = errno;

                    debug (Process)
                        Stdout.formatln("Could not wait on child process '{0}' ({1}): ({2}) {3}",
                                        _args[0], _pid, result.status, lastSysErrorMsg());
                }
                clean();
            }
            else
            {
                result.reason = Result.Reason.Error;
                result.status = -1;

                debug (Process)
                    Stdout.formatln("Child process '{0}' is not running", _args[0]);
            }
            return result;
        }
        else
        {
            assert(false, "tango.sys.Process: Unsupported platform");
        }
    }

    /**
     * Kill a running process. This method will not return until the process
     * has been killed.
     *
     * Throws:
     * $D_CODE(ProcessKillException) if the process could not be killed;
     * $D_CODE(ProcessWaitException) if we could not wait on the process after
     * killing it.
     *
     * Remarks:
     * After calling this method you will not be able to call $D_CODE(wait())
     * on the process.
     */
    public void kill()
    {
        version (Windows)
        {
            if (_running)
            {
                assert(_info !is null);

                if (TerminateProcess(_info.hProcess, cast(UINT) -1))
                {
                    assert(_info !is null);

                    scope(exit)
                    {
                        CloseHandle(info.hProcess);
                        clean();
                    }

                    // FIXME: We should probably use a timeout here
                    if (WaitForSingleObject(_info.hProcess, INFINITE) == WAIT_FAILED)
                    {
                        throw new ProcessWaitException(cast(int) _info.dwProcessId,
                                                       __FILE__, __LINE__);
                    }
                }
                else
                {
                    throw new ProcessKillException(cast(int) _info.dwProcessId,
                                                   __FILE__, __LINE__);
                }
            }
            else
            {
                debug (Process)
                    Stdout.print("Tried to kill an invalid process");
            }
        }
        else version (Posix)
        {
            if (_running)
            {
                int rc;

                assert(_pid > 0);

                if (.kill(_pid, SIGTERM) != -1)
                {
                    scope(exit)
                        clean();

                    // FIXME: is this loop really needed?
                    for (uint i = 0; i < 100; i++)
                    {
                        rc = waitpid(pid, null, WNOHANG | WUNTRACED);
                        if (rc == _pid)
                        {
                            break;
                        }
                        else if (rc == -1)
                        {
                            throw new ProcessWaitException(cast(int) _pid, __FILE__, __LINE__);
                        }
                        usleep(50000);
                    }
                }
                else
                {
                    throw new ProcessKillException(_pid, __FILE__, __LINE__);
                }
            }
            else
            {
                debug (Process)
                    Stdout.print("Tried to kill an invalid process");
            }
        }
        else
        {
            assert(false, "tango.sys.Process: Unsupported platform");
        }
    }

    /**
     * Split a string containing the command line used to invoke a program
     * and return and array with the parsed arguments. The double-quotes (")
     * character can be used to specify arguments with embedded spaces.
     * e.g. first "second param" third
     */
    protected static char[][] splitArgs(inout char[] command, char[] delims = " \t\r\n")
    in
    {
        assert(find(delims, '"') == false,
               "The argument delimiter string cannot contain a double quotes ('\"') character");
    }
    body
    {
        enum State
        {
            Start,
            FindDelimiter,
            InsideQuotes
        }

        char[][]    args = null;
        char[][]    chunks = null;
        int         start = -1;
        char        c;
        int         i;
        State       state = State.Start;

        // Append an argument to the 'args' array using the 'chunks' array
        // and the current position in the 'command' string as the source.
        void appendChunksAsArg()
        {
            uint argPos;

            if (chunks.length > 0)
            {
                // Create the array element corresponding to the argument by
                // appending the first chunk.
                args   ~= chunks[0];
                argPos  = args.length - 1;

                for (uint chunkPos = 1; chunkPos < chunks.length; ++chunkPos)
                {
                    args[argPos] ~= chunks[chunkPos];
                }

                if (start != -1)
                {
                    args[argPos] ~= command[start .. i];
                }
                chunks.length = 0;
            }
            else
            {
                if (start != -1)
                {
                    args ~= command[start .. i];
                }
            }
            start = -1;
        }

        for (i = 0; i < command.length; i++)
        {
            c = command[i];

            switch (state)
            {
                // Start looking for an argument.
                case State.Start:
                    if (c == '"')
                    {
                        state = State.InsideQuotes;
                    }
                    else if (!find(delims, c))
                    {
                        start = i;
                        state = State.FindDelimiter;
                    }
                    else
                    {
                        appendChunksAsArg();
                    }
                    break;

                // Find the ending delimiter for an argument.
                case State.FindDelimiter:
                    if (c == '"')
                    {
                        // If we find a quotes character this means that we've
                        // found a quoted section of an argument. (e.g.
                        // abc"def"ghi). The quoted section will be appended
                        // to the preceding part of the argument. This is also
                        // what Unix shells do (i.e. a"b"c becomes abc).
                        if (start != -1)
                        {
                            chunks ~= command[start .. i];
                            start = -1;
                        }
                        state = State.InsideQuotes;
                    }
                    else if (find(delims, c))
                    {
                        appendChunksAsArg();
                        state = State.Start;
                    }
                    break;

                // Inside a quoted argument or section of an argument.
                case State.InsideQuotes:
                    if (start == -1)
                    {
                        start = i;
                    }

                    if (c == '"')
                    {
                        chunks ~= command[start .. i];
                        start = -1;
                        state = State.Start;
                    }
                    break;
            }
        }

        // Add the last argument (if there is one)
        appendChunksAsArg();

        return args;
    }

    /**
     * Find a character in a string.
     */
    protected static bool find (char[] list, char match)
    {
        foreach (c; list)
        {
            if (c is match)
                return true;
        }
        return false;
    }

    /**
     * Reset the object to its initial state.
     */
    protected void clean()
    {
        _running = false;
        delete _stdin;
        delete _stdout;
        delete _stderr;
    }

    version (Windows)
    {
        /**
         * Convert an array of strings to a buffer containing each string
         * separated by a null character and an additional null character at
         * the end of it. This is the format expected by the CreateProcess()
         * Windows API.
         */
        protected static char[] toNullEndedBuffer(char[][] src)
        {
            char[]  dest = null;
            // Add space for a \0 after each string and a terminating \0
            size_t  length = src.length + 1;
            uint    pos = 0;

            foreach(char[] str; src)
            {
                length += str.length;   // total length of strings
            }

            dest = new char[length];

            foreach(char[] str; src)
            {
                dest[pos .. pos + str.length] = str;
                pos += src.length;
                envptr[pos++] = '\0';
            }

            return dest;
        }
    }
    else version (Posix)
    {
        /**
         * Convert an array of strings to an array of pointers to char with
         * a terminating null character (C strings). The resulting array
         * has a null pointer at the end. This is the format expected by
         * the execv*() family of POSIX functions.
         */
        protected static char*[] toNullEndedArray(char[][] src)
        out (result)
        {
            if (result !is null)
            {
                int i = result.length - 1;

                // Verify that the returned array has the format expected
                // by execv() and execve().
                assert(result.length == src.length + 1);
                assert(result[i] == null);

                while (--i >= 0)
                {
                    assert(result[i] !is null);
                    assert(*(result[i] + src[i].length) == '\0');
                }
            }
        }
        body
        {
            if (src !is null)
            {
                char*[] dest = new char*[src.length + 1];
                int     i = src.length;

                // Add terminating null pointer to the array
                dest[i] = null;

                while (--i >= 0)
                {
                    // Add a terminating null character to each string
                    dest[i] = toUtf8z(src[i]);
                }
                return dest;
            }
            else
            {
                return null;
            }
        }

        /**
         * Execute a process by looking up a file in the system path, passing
         * the array of arguments and the the environment variables. This
         * method is a combination of the execve() and execvp() POSIX system
         * calls.
         */
        protected static int execvpe(char[] filename, char*[] argv, char*[] envp)
        in
        {
            assert(filename !is null);
        }
        body
        {
            int rc = -1;
            char* str;

            if (!find(filename, FileConst.PathSeparatorChar) &&
                (str = getenv("PATH")) !is null)
            {
                char[]  envPath = str[0 .. strlen(str)];
                char[]  path;

                // Preallocate the buffer we'll use to hold the file's
                // absolute path.
                path.length = 64 + filename.length;
                path.length = 0;

                foreach (path; new SimpleIterator(envPath, ":"))
                {
                    if (path[path.length - 1] != FileConst.PathSeparatorChar)
                    {
                        path ~= FileConst.PathSeparatorChar;
                    }
                    path ~= filename;

                    rc = execve(path.ptr, argv.ptr, envp.ptr);
                    // If the process execution failed because of an error
                    // other than ENOENT (No such file or directory) we
                    // abort the loop.
                    if (rc == -1 && errno != ENOENT)
                    {
                        break;
                    }
                }
            }
            else
            {
                rc = execve(argv[0], argv.ptr, envp.ptr);
            }
            return rc;
        }
    }
}


/**
 * Base class for all the exceptions thrown by the Process methods.
 */
class ProcessException: Exception
{
    protected this(char[] msg, pid_t pid)
    {
        super(Formatter.format(msg, pid, lastSysErrorMsg()));
    }

    protected this(char[] msg, char[] command)
    {
        super(Formatter.format(msg, command, lastSysErrorMsg()));
    }
}

/**
 * Exception thrown when the process cannot be created.
 */
class ProcessCreateException: ProcessException
{
    public this(char[] command, char[] file, uint line)
    {
        super("Could not create process for {0}: {1}", command);
    }
}

/**
 * Exception thrown when the parent process cannot be forked.
 *
 * This exception will only be thrown on POSIX-compatible platforms.
 */
class ProcessForkException: ProcessException
{
    public this(pid_t pid, char[] file, uint line)
    {
        super("Could not fork process {0}: {1}", pid);
    }
}

/**
 * Exception thrown when the process cannot be killed.
 */
class ProcessKillException: ProcessException
{
    public this(pid_t pid, char[] file, uint line)
    {
        super("Could not kill process {0}: {1}", pid);
    }
}

/**
 * Exception thrown when the parent process tries to wait on the child
 * process and fails.
 */
class ProcessWaitException: ProcessException
{
    public this(pid_t pid, char[] file, uint line)
    {
        super("Could not wait on process {0}: {1}", pid);
    }
}


debug (UnitTest)
{
    private import tango.text.LineIterator;

    unittest
    {
        char[][] params;
        char[] command = "echo ";
        uint i;

        params ~= "one";
        params ~= "two";
        params ~= "three";

        command ~= '"';
        for (i = 0; i < params.length; ++i)
        {
            command ~= params[i];
            if (i != params.length - 1)
            {
                command ~= '\n';
            }
        }
        command ~= '"';

        try
        {
            auto p = new Process(command);

            p.execute();

            i = 0;
            foreach (line; new LineIterator(p.stdout))
            {
                assert(line == params[i++]);
            }

            auto result = p.wait();

            assert(result.reason == Process.Result.Reason.Exit && result.status == 0);
        }
        catch (ProcessException e)
        {
            Stdout.formatln("Program execution failed: {0}", e.toUtf8());
        }
    }
}
