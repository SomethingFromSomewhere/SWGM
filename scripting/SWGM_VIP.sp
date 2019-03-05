#include <vip_core>
#include <swgm>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo =
{
	name 			= 		"[SWGM] VIP",
	author 			= 		"Someone",
	description 	= 		"Выдача VIP-статуса для игроков, состоящих в Steam группе.",
	version 		= 		"1.8",
	url 			= 		"http://hlmod.ru | https://discord.gg/UfD3dSa"
};

ConVar CVAR;

char g_sVIPGroup[32];
bool g_bVIP[MAXPLAYERS+1], g_bLoaded[MAXPLAYERS+1];

public void OnPluginStart()
{
	(CVAR = CreateConVar("sm_swgm_vip_group",		"vip",		"VIP группа.")).AddChangeHook(ChangeCvar_Group);
	CVAR.GetString(g_sVIPGroup, sizeof(g_sVIPGroup));
	
	
	LoadTranslations("vip_modules.phrases");
	AutoExecConfig(true, "swgm_vip", "sourcemod/swgm");
}

public void ChangeCvar_Group(ConVar convar, const char[] oldValue, const char[] newValue)
{
	convar.GetString(g_sVIPGroup, sizeof(g_sVIPGroup));
	if(!VIP_IsValidVIPGroup(g_sVIPGroup))
	{
		LogError("Group `%s` not found! Check convar sm_swgm_vip_group!", g_sVIPGroup);
	}
}

public void VIP_OnClientLoaded(int iClient, bool bIsVIP)
{
	if(!IsFakeClient(iClient) && SWGM_IsPlayerValidated(iClient) && SWGM_GetPlayerStatus(iClient) > LEAVER && !bIsVIP)
	{
		VIP_GiveClientVIP(0, iClient, 0, g_sVIPGroup, false);
		g_bVIP[iClient] = true;
	}
	g_bLoaded[iClient] = true;
}

public void OnClientDisconnect(int iClient)
{
	g_bLoaded[iClient] = false;
}

public void SWGM_OnJoinGroup(int iClient, bool IsOfficer)
{
	if(g_bLoaded[iClient] && !VIP_IsClientVIP(iClient))
	{
		VIP_GiveClientVIP(0, iClient, 0, g_sVIPGroup, false);
		g_bVIP[iClient] = true;
		VIP_PrintToChatClient(iClient, "%t", "SWGM_VIP_Give");
	}
}

public void SWGM_OnLeaveGroup(int iClient)
{
	if(g_bLoaded[iClient] && g_bVIP[iClient] && VIP_IsClientVIP(iClient))
	{
		static char sBuffer[32];
		if(VIP_GetClientVIPGroup(iClient, sBuffer, sizeof(sBuffer)) && !strcmp(sBuffer, g_sVIPGroup))
		{
			g_bVIP[iClient] = false;
			VIP_RemoveClientVIP2(0, iClient, false, false);
			VIP_PrintToChatClient(iClient, "%t", "SWGM_VIP_Take");
		}
	}
}