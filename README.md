# ftail

Tail long running processes into a file, because the usual tail command waits for the executable to finish to output, ftail doesn't

```
ftail -[OPTION(s)] [OUTPUT_FILE] [SUBPROCESS args]
Description
 Tail a long running process into a file, supports stdin
Options
 n  xx     number of lines (xx) 
           shows all incoming stdin lines,
           default is -n 10

 c         clears stdout, only shows last n lines
           should be used along with o flag, otherwise no effect 
 
 o         output to stdout

 f         write to file

 h         print help
```

Example Usage
If you have a not so important program, but would like to keep track of its last stdout log outputs

```
my_not_so_important_exe *args | ftail -nof 30 /tmp/my_not_so_important_exe.log
```
will output all lines to stdout but writes the recent 30 lines to the file

```
my_not_so_important_exe *args | ftail -nocf 30 /tmp/my_not_so_important_exe.log
```
will clear the console and output the last 30 lines to stdout and writes them to the file
```
ftail -nfo 30 /tmp/my_not_so_important_exe.log my_not_so_important_exe *args
ftail -nfco 30 /tmp/my_not_so_important_exe.log my_not_so_important_exe *args
```
same thing, this syntax is more useful for when running with sudo or non shell environments

if output to file is not needed and only to console
```
ftail -noc 30 my_not_so_important_exe *args
```

the order of options don't matter, but if n and f are used, the next argument should be number of lines and then output file path

DISCLAIMER:
  Not tested for every use case, just made it for my very specific use and it works for me, so you can try it yourself

  Since it writes the entire file for every new line, not recommended to be used with larger n on disk, recommended to be used only with memory filesystems
