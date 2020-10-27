Sourcemod plugins which are developed by us are auto recompiled on each server instance.

However, if we want to keep some sp that aren't managed by us and we don't expect them
to be updated so often -- we should keep them in the /external folder. That folder is
ignored during compilation sequence but git tracks all the changes.

TL;DR - We put anything we don't want to be compiled during update sequence in /external folder.
