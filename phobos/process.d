
/*
 *  Copyright (C) 2003-2004 by Digital Mars, www.digitalmars.com
 *  Written by Matthew Wilson and Walter Bright
 *
 *  Incorporating idea (for execvpe() on Linux) from Russ Lewis
 *
 *  Updated: 21st August 2004
 *
 *  This software is provided 'as-is', without any express or implied
 *  warranty. In no event will the authors be held liable for any damages
 *  arising from the use of this software.
 *
 *  Permission is granted to anyone to use this software for any purpose,
 *  including commercial applications, and to alter it and redistribute it
 *  freely, subject to the following restrictions:
 *
 *  o  The origin of this software must not be misrepresented; you must not
 *     claim that you wrote the original software. If you use this software
 *     in a product, an acknowledgment in the product documentation would be
 *     appreciated but is not required.
 *  o  Altered source versions must be plainly marked as such, and must not
 *     be misrepresented as being the original software.
 *  o  This notice may not be removed or altered from any source
 *     distribution.
 */

/**
 * Macros:
 *	WIKI=Phobos/StdProcess
 */

module phobos.process;

private import phobos.c.stdlib;
private import phobos.c.string;
private import phobos.string;
private import phobos.c.process;

/**
 * Execute command in a _command shell.
 *
 * Returns: exit status of command
 */

int system(char[] command)
{
    return phobos.c.process.system(toUtf8z(command));
}

private void toAStringz(char[][] a, char**az)
{
    foreach(char[] s; a)
    {
        *az++ = toUtf8z(s);
    }
    *az = null;
}


/* ========================================================== */

//version (Windows)
//{
//    int spawnvp(int mode, char[] pathname, char[][] argv)
//    {
//	char** argv_ = cast(char**)alloca((char*).sizeof * (1 + argv.length));
//
//	toAStringz(argv, argv_);
//
//	return phobos.c.process.spawnvp(mode, toUtf8z(pathname), argv_);
//    }
//}

// Incorporating idea (for spawnvp() on linux) from Dave Fladebo

alias phobos.c.process._P_WAIT P_WAIT;
alias phobos.c.process._P_NOWAIT P_NOWAIT;

int spawnvp(int mode, char[] pathname, char[][] argv)
{
    char** argv_ = cast(char**)alloca((char*).sizeof * (1 + argv.length));

    toAStringz(argv, argv_);

    version(linux)
    {
        return _spawnvp(mode, toUtf8z(pathname), argv_);
    }
    else
    {
        return phobos.c.process.spawnvp(mode, toUtf8z(pathname), argv_);
    }
}

version(linux)
{
private import phobos.c.linux.linux;
private import tango.stdc.posix.unistd;
private import tango.stdc.posix.sys.wait;
int _spawnvp(int mode, char *pathname, char **argv)
{
    int retval = 0;
    pid_t pid = fork();

    if(!pid)
    {   // child
        phobos.c.process.execvp(pathname, argv);
        goto Lerror;
    }
    else if(pid > 0)
    {   // parent
        if(mode == _P_NOWAIT)
        {
            retval = pid; // caller waits
        }
        else
        {
            while(1)
            {
                int status;
                pid_t wpid = waitpid(pid, &status, 0);
                if(exited(status))
                {
                    retval = exitstatus(status);
                    break;
                }
                else if(signaled(status))
                {
                    retval = -termsig(status);
                    break;
                }
                else if(stopped(status)) // ptrace support
                    continue;
                else
                    goto Lerror;
            }
        }

        return retval;
    }

Lerror:
    retval = getErrno;
    throw new Exception("Cannot spawn " ~ toUtf8(pathname) ~ "; " ~ toUtf8(strerror(retval)) ~ " [errno " ~ toUtf8(retval) ~ "]");
}   // _spawnvp
private
{
bool stopped(int status)    { return cast(bool)((status & 0xff) == 0x7f); }
bool signaled(int status)   { return cast(bool)((cast(char)((status & 0x7f) + 1) >> 1) > 0); }
int  termsig(int status)    { return status & 0x7f; }
bool exited(int status)     { return cast(bool)((status & 0x7f) == 0); }
int  exitstatus(int status) { return (status & 0xff00) >> 8; }
}   // private
}   // version(linux)

/* ========================================================== */

/**
 * Execute program specified by pathname, passing it the arguments (argv)
 * and the environment (envp), returning the exit status.
 * The 'p' versions of exec search the PATH environment variable
 * setting for the program.
 */

int execv(char[] pathname, char[][] argv)
{
    char** argv_ = cast(char**)alloca((char*).sizeof * (1 + argv.length));

    toAStringz(argv, argv_);

    return phobos.c.process.execv(toUtf8z(pathname), argv_);
}

/** ditto */
int execve(char[] pathname, char[][] argv, char[][] envp)
{
    char** argv_ = cast(char**)alloca((char*).sizeof * (1 + argv.length));
    char** envp_ = cast(char**)alloca((char*).sizeof * (1 + envp.length));

    toAStringz(argv, argv_);
    toAStringz(envp, envp_);

    return phobos.c.process.execve(toUtf8z(pathname), argv_, envp_);
}

/** ditto */
int execvp(char[] pathname, char[][] argv)
{
    char** argv_ = cast(char**)alloca((char*).sizeof * (1 + argv.length));

    toAStringz(argv, argv_);

    return phobos.c.process.execvp(toUtf8z(pathname), argv_);
}

/** ditto */
int execvpe(char[] pathname, char[][] argv, char[][] envp)
{
version(linux)
{
    // Is pathname rooted?
    if(pathname[0] == '/')
    {
        // Yes, so just call execve()
        return execve(pathname, argv, envp);
    }
    else
    {
        // No, so must traverse PATHs, looking for first match
        char[][]    envPaths    =   phobos.string.split(phobos.string.toUtf8(phobos.c.stdlib.getenv("PATH")), ":");
        int         iRet        =   0;

        // Note: if any call to execve() succeeds, this process will cease 
        // execution, so there's no need to check the execve() result through
        // the loop.

        foreach(char[] pathDir; envPaths)
        {
            char[]  composite   =   pathDir ~ "/" ~ pathname;

            iRet = execve(composite, argv, envp);
        }
        if(0 != iRet)
        {
            iRet = execve(pathname, argv, envp);
        }

        return iRet;
    }
}
else version(Windows)
{
    char** argv_ = cast(char**)alloca((char*).sizeof * (1 + argv.length));
    char** envp_ = cast(char**)alloca((char*).sizeof * (1 + envp.length));

    toAStringz(argv, argv_);
    toAStringz(envp, envp_);

    return phobos.c.process.execvpe(toUtf8z(pathname), argv_, envp_);
}
else
{
    static assert(0);
} // version
}

/* ////////////////////////////////////////////////////////////////////////// */

version(MainTest)
{
    int main(char[][] args)
    {
        if(args.length < 2)
        {
            printf("Must supply executable (and optional arguments)\n");

            return 1;
        }
        else
        {
            char[][]    dummy_env;
            
            dummy_env ~= "VAL0=value";
            dummy_env ~= "VAL1=value";

/+
            foreach(char[] arg; args)
            {
                printf("%.*s\n", arg);
            }
+/

//          int i = execv(args[1], args[1 .. args.length]);
//          int i = execvp(args[1], args[1 .. args.length]);
            int i = execvpe(args[1], args[1 .. args.length], dummy_env);

            printf("exec??() has returned! Error code: %d; errno: %d\n", i, /* phobos.c.stdlib.getErrno() */-1);

            return 0;
        }
    }
}

/* ////////////////////////////////////////////////////////////////////////// */
