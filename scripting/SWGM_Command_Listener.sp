#include <swgm>
#include <multicolors>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo =
{
	name    =	"[SWGM] Command Listener",
	author  = 	"Someone",
	version	= 	"1.2",
	url     = 	"http://hlmod.ru | https://discord.gg/UfD3dSa"
};

public void OnAllPluginsLoaded()
{
	LoadTranslations("swgm_cl.phrases");
	LoadConfig();
	RegAdminCmd("sm_swgm_cl_reload", CMD_RELOAD, ADMFLAG_ROOT);
}

public Action CMD_RELOAD(int iClient, int iArgs)
{
	LoadConfig();
}

public Action Check(int iClient, const char[] sCommand, int iArgc)
{
	if(iClient != 0 && SWGM_IsPlayerValidated(iClient) && !SWGM_InGroup(iClient))
	{
		CPrintToChat(iClient, "%t", "JoinSteam");
		return Plugin_Stop;
	}
	return Plugin_Continue;
}

void LoadConfig()
{
	KeyValues Kv = new KeyValues("Command_Listener");
	
	char sBuffer[256];
	BuildPath(Path_SM, sBuffer, sizeof(sBuffer), "configs/swgm/command_listener.ini");
	if (!FileToKeyValues(Kv, sBuffer)) SetFailState("Файл конфигурации не найден %s", sBuffer);
	
	if (Kv.GotoFirstSubKey())
	{
		do
		{
			if (Kv.GetSectionName(sBuffer, sizeof(sBuffer)))
			{
				AddCommandListener(Check, sBuffer); 
			}
		} 
		while (Kv.GotoNextKey());
	}
	delete Kv;
}
