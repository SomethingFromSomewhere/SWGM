#include <steamworks>
#include <swgm>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo =
{
	name = "Steam Works Group Manager",
	author = "Someone",
	description = "Steam group membership check features for plugins",
	version = "1.9",
	url = "http://hlmod.ru | https://discord.gg/UfD3dSa"
};

Handle 	g_hForward_OnLeaveCheck, 		g_hForward_OnJoinCheck, g_hTimer;
int 		g_iGroupID, 					g_iAccountID[MAXPLAYERS+1];
Status 	g_iPlayerStatus[MAXPLAYERS+1];

public APLRes AskPluginLoad2(Handle myself, bool late, char[] sError, int err_max)
{
	g_hForward_OnLeaveCheck = CreateGlobalForward("SWGM_OnLeaveGroup", 	ET_Ignore, Param_Cell);
	g_hForward_OnJoinCheck 	= CreateGlobalForward("SWGM_OnJoinGroup", 	ET_Ignore, Param_Cell, Param_Cell);

	CreateNative("SWGM_InGroup", 			Native_InGroup);
	CreateNative("SWGM_InGroupOfficer", 	Native_InGroupOfficer);
	CreateNative("SWGM_GetPlayerStatus", 	Native_GetPlayerStatus);
	CreateNative("SWGM_CheckPlayer", 		Native_CheckPlayer);
	CreateNative("SWGM_IsPlayerValidated", 	Native_IsPlayerValidated);

	RegPluginLibrary("SWGM");

	return APLRes_Success;
}

public void OnPluginStart()
{
	ConVar CVAR;

	(CVAR = CreateConVar("sm_swgm_groupid",		"0",	"Steam Group ID.",						_, 		true, 		0.0)).AddChangeHook(OnGroupChange);
	g_iGroupID = CVAR.IntValue;
	
	(CVAR = CreateConVar("sm_swgm_timer",		"60.0",	"Interval beetwen steam group checks.",	_, 		true, 		0.0)).AddChangeHook(OnTimeChange);
	g_hTimer = CreateTimer(CVAR.FloatValue, 		Check_Timer, 									_, 	TIMER_REPEAT		);
	
	RegAdminCmd("sm_swgm_check", 	CMD_Check, 	ADMFLAG_ROOT);

	AutoExecConfig(true, "swgm", "sourcemod/swgm");
}

public void OnGroupChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_iGroupID = convar.IntValue;
	
	for(int i = 1; i <= MaxClients; ++i)	if(IsClientInGame(i) && !IsFakeClient(i))
	{
		SteamWorks_GetUserGroupStatusAuthID(GetSteamAccountID(i), g_iGroupID);
	}
}

public void OnTimeChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if(g_hTimer) KillTimer(g_hTimer); g_hTimer = null;
	g_hTimer = CreateTimer(convar.FloatValue, Check_Timer, _, TIMER_REPEAT);
}

public Action Check_Timer(Handle hTimer)
{
	Check();
	return Plugin_Continue;
}

public void OnConfigsExecuted()
{
	if(g_iGroupID == 0)
	{
		LogError("[SWGM] Set yours Steam group ID. Group ID `0` is default value. Example: sm_swgm_groupid `ID`.");
	}
}

public Action CMD_Check(int iClient, int args)
{
	Check();
	ReplyToCommand(iClient, "[SWGM] All players have been checked.");
	return Plugin_Handled;
}

void Check()
{
	static int i;
	for (i = 1; i <= MaxClients; ++i) if(g_iPlayerStatus[i] != UNASSIGNED && g_iPlayerStatus[i] != LEAVER)
	{
		SteamWorks_GetUserGroupStatusAuthID(g_iAccountID[i], g_iGroupID);
	}
}

public void OnClientDisconnect(int iClient)
{
	g_iAccountID[iClient] = 0;
	g_iPlayerStatus[iClient] = UNASSIGNED;
}

public void SteamWorks_OnValidateClient(int iOwnerAuthID, int iAccountID)
{
	SteamWorks_GetUserGroupStatusAuthID(iAccountID, g_iGroupID);
}

public void SteamWorks_OnClientGroupStatus(int iAccountID, int iGroupID, bool bIsMember, bool bIsOfficer)
{
	static int iClient;
	if(iGroupID == g_iGroupID && (iClient = GetUserFromAccountID(iAccountID)) != -1)
	{
		if(!bIsMember && g_iPlayerStatus[iClient] > LEAVER)
		{
			g_iPlayerStatus[iClient] = LEAVER;

			Call_StartForward(g_hForward_OnLeaveCheck);
			Call_PushCell(iClient);
			Call_Finish();
		}
		else if(bIsMember && (g_iPlayerStatus[iClient] == NO_GROUP || g_iPlayerStatus[iClient] == UNASSIGNED))
		{
			g_iPlayerStatus[iClient] =  bIsOfficer ? OFFICER:MEMBER;
			
			Call_StartForward(g_hForward_OnJoinCheck);
			Call_PushCell(iClient);
			Call_PushCell(bIsOfficer);
			Call_Finish();
		}
	}
}

public int GetUserFromAccountID(int iAccountID)
{
	static int i;
	for (i = 1; i <= MaxClients; ++i) if(IsClientConnected(i) && !IsFakeClient(i))
    {
		if(g_iAccountID[i] == 0)
		{
			g_iPlayerStatus[i] = NO_GROUP;
			if((g_iAccountID[i] = GetSteamAccountID(i)) == iAccountID)
			{
				return i;
			}
		}
		else if(g_iAccountID[i] == iAccountID)
		{
			return i;
		}
	}
	return -1;
}

public int Native_InGroup(Handle hPlugin, int iClient)
{
	return CheckClient((iClient = GetNativeCell(1)), "InGroup") ? (g_iPlayerStatus[iClient] > LEAVER):false;
}

public int Native_InGroupOfficer(Handle hPlugin, int iClient)
{
	return CheckClient((iClient = GetNativeCell(1)), "InGroupOfficer") ? (g_iPlayerStatus[iClient] == OFFICER):false;
}

public int Native_GetPlayerStatus(Handle hPlugin, int iClient)
{
	return CheckClient((iClient = GetNativeCell(1)), "GetPlayerStatus", false) ? view_as<int>(g_iPlayerStatus[iClient]):-1;
}

public int Native_CheckPlayer(Handle hPlugin, int iClient)
{
	if (CheckClient((iClient = GetNativeCell(1)), "CheckPlayer", false))
	{
		SteamWorks_GetUserGroupStatusAuthID(g_iAccountID[iClient], g_iGroupID);
	}
}

public int Native_IsPlayerValidated(Handle hPlugin, int iClient)
{
	return ((iClient = GetNativeCell(1)) > 0 || iClient <= MaxClients) ? view_as<int>((g_iPlayerStatus[iClient] != UNASSIGNED)):
																		ThrowNativeError(SP_ERROR_NATIVE, 
																		"[IsPlayerValidated] Client index %i is invalid.", 
																		iClient);
}


bool CheckClient(int iClient, const char[] sFunction, bool bCheckValidation = true)
{
	static int iClientError;
	static const char sError[][] = {	"invalid", 
										"not validated", 
										"a bot"				};

	if((iClientError = Function_GetClientError(iClient, bCheckValidation)) != 3)	
	{
										ThrowNativeError(SP_ERROR_NATIVE, 
										"[%s] Client index %i is %s.", 
										sFunction, iClient, 
										sError[iClientError]);
	}
	return true;
}

int Function_GetClientError(int iClient, bool bCheckValidation)
{
	if (iClient < 1 || iClient > MaxClients)												return 0;
	else if (bCheckValidation && g_iPlayerStatus[iClient] == UNASSIGNED)					return 1;
	else if (IsFakeClient(iClient))															return 2;
	return 3;
}