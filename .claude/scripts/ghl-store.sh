# Sourced by ghl-headers.sh and ghl-values-api.sh, never run on its own.
#
# Reads one GoHighLevel item from the computer's own password store, with only
# what ships with the operating system:
#   - a Mac: the Keychain, through the built-in security command
#   - Windows: Credential Manager, through Windows PowerShell with no extra
#     modules (Add-Type calls the Windows credential reader directly)
#
# The founder adds the item themselves, by clicking, as connect-tools sets out.
# The item's name is fixed. Its account (Mac) or user name (Windows) holds the
# Location ID, and its password holds the key.
#
# ghl_store_read <item name> sets:
#   ghl_found    yes when the item is there, no when it is not
#   ghl_allowed  yes when its password could be read, no when the Mac refused
#   ghl_loc      the Location ID
#   ghl_key      the key
# It prints nothing, and nothing here ever writes the key anywhere.

# The two items. The first is the connection's key, kept. The second is only
# for ghl-values, made and deleted by the founder for one job.
ghl_conn_item='Launchhouse GoHighLevel'
ghl_values_item='Launchhouse GoHighLevel values'

ghl_clean() { tr -d '\r' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'; }

ghl_good_key() { case $1 in ''|*[!A-Za-z0-9._-]*) return 1 ;; esac; return 0; }
ghl_good_loc() { case $1 in ''|*[!A-Za-z0-9]*) return 1 ;; esac; return 0; }

ghl_system() {
  case $(uname -s 2>/dev/null) in
    Darwin) printf mac ;;
    MINGW*|MSYS*|CYGWIN*|*_NT*) printf windows ;;
    *) printf other ;;
  esac
}

# A small Windows PowerShell program that reads one generic credential and
# prints its user name, then its password, one per line. It is passed encoded,
# so no quoting can change it on the way.
ghl_ps() {
  cat <<EOF
\$ErrorActionPreference = 'Stop'
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class LhCred {
  [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
  private struct CREDENTIAL {
    public int Flags; public int Type; public string TargetName; public string Comment;
    public System.Runtime.InteropServices.ComTypes.FILETIME LastWritten;
    public int CredentialBlobSize; public IntPtr CredentialBlob; public int Persist;
    public int AttributeCount; public IntPtr Attributes; public string TargetAlias; public string UserName;
  }
  [DllImport("advapi32.dll", EntryPoint = "CredReadW", CharSet = CharSet.Unicode, SetLastError = true)]
  private static extern bool CredRead(string target, int type, int flags, out IntPtr cred);
  [DllImport("advapi32.dll")]
  private static extern void CredFree(IntPtr cred);
  public static string[] Read(string target) {
    IntPtr p;
    if (!CredRead(target, 1, 0, out p)) return null;
    try {
      CREDENTIAL c = (CREDENTIAL)Marshal.PtrToStructure(p, typeof(CREDENTIAL));
      string s = c.CredentialBlobSize > 0 ? Marshal.PtrToStringUni(c.CredentialBlob, c.CredentialBlobSize / 2) : "";
      return new string[] { c.UserName, s };
    } finally { CredFree(p); }
  }
}
'@
\$r = [LhCred]::Read('$1')
if (\$null -eq \$r) { exit 3 }
[Console]::Out.Write([string]\$r[0] + "\`n" + [string]\$r[1] + "\`n")
EOF
}

ghl_store_read() {
  ghl_found=no; ghl_allowed=no; ghl_loc=; ghl_key=
  case $(ghl_system) in
    mac)
      attrs=$(security find-generic-password -s "$1" 2>/dev/null) || return 1
      ghl_found=yes
      ghl_loc=$(printf '%s\n' "$attrs" | sed -n 's/^[[:space:]]*"acct"<blob>="\(.*\)"$/\1/p' | head -1 | ghl_clean)
      ghl_key=$(security find-generic-password -s "$1" -w 2>/dev/null) || { ghl_key=; return 1; }
      ghl_key=$(printf '%s' "$ghl_key" | ghl_clean)
      ghl_allowed=yes ;;
    windows)
      enc=$(ghl_ps "$1" | iconv -f UTF-8 -t UTF-16LE | base64 | tr -d '\n\r')
      out=$(powershell.exe -NoProfile -NonInteractive -EncodedCommand "$enc" < /dev/null 2>/dev/null) || return 1
      ghl_found=yes; ghl_allowed=yes
      ghl_loc=$(printf '%s\n' "$out" | sed -n 1p | ghl_clean)
      ghl_key=$(printf '%s\n' "$out" | sed -n 2p | ghl_clean) ;;
    *) return 1 ;;
  esac
  return 0
}
