
private import  tango.io.Console,
                tango.io.FileScan,
                tango.io.FileConst;

/*******************************************************************************

        This example sweeps a named sub-directory tree for html files,
        and moves them to the current directory. The existing directory 
        hierarchy is flattened into a naming sheme where a '.' is used
        to replace the traditional path-separator

        Used by the Tango project to help manage renderings of the source 
        code.

*******************************************************************************/

void main(char[][] args)
{       
        void process (File file)
        {
                // get a mutated target filename
                auto dst = file.getPath.replace (file.toUtf8.dup, FileConst.PathSeparatorChar, '.');

                // rename the file
                file.rename (new FilePath (dst));
        }


        // sweep all html files in the specified subdir
        if (args.length is 2)
           (new FileScan).sweep(args[1], "html").files(&process);       
        else
           Cout ("usage is filebubbler subdir").newline;
}

