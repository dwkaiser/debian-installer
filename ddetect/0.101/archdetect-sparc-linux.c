#include "archdetect.h"
#include <sys/utsname.h>
#include <string.h>

const char *subarch_analyze(void) 
{
  struct utsname buf;

  if (uname(&buf) == 0)
  {
    if (!strcmp(buf.machine, "sparc64"))
      return "sparc64";
    else
      return "sparc32";
  }
  return "unknown";
}
