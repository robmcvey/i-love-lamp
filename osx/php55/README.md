## PHP 5.5.3

There is a bug when installing GD with freetype.

https://bugs.php.net/bug.php?id=64405

### Solution

Update `configure` from:

`if test -f "$i/include/freetype2/freetype/freetype.h"; then`

To:

`if test -f "$i/include/freetype2/freetype/freetype.h" || test -f "$i/include/freetype2/freetype.h";  then`

