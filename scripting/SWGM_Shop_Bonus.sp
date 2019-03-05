#include <swgm>
#include <shop>

public Plugin myinfo =
{
	name = "[SWGM] Shop Bonus",
	author = "Someone",
	description = "Бонусы для игроков, вступивших в Steam группу.",
	version = "1.3",
	url = "http://hlmod.ru"
};

#pragma semicolon 1
#pragma newdecls required

ConVar CVAR;

float g_fCredits, g_fDisc, g_fInterval;
bool g_bType, g_bPlay;
int g_iCredits;
Handle g_hTimer[MAXPLAYERS+1];

public void OnPluginStart()
{
	(CVAR = CreateConVar("sm_swgm_shop_bonus_type",		"1",	"0 - кредиты умножаются. 1 - кредиты прибавляются.", _, true, 0.0, true, 1.0)).AddChangeHook(OnTypeChange);
	g_bType = CVAR.BoolValue;
	
	(CVAR = CreateConVar("sm_swgm_shop_bonus_amount",		"2.0",	"Кол-во прибавляемых/умножаемых кредитов.", _, true, 0.0)).AddChangeHook(OnAmountChange);
	g_fCredits = CVAR.FloatValue;
	
	(CVAR = CreateConVar("sm_swgm_shop_bonus_credits",		"5",	"Кол-во выдаваемых кредитов раз в N секунд.", _, true, 0.0)).AddChangeHook(OnCreditsChange);
	g_iCredits = CVAR.IntValue;
	
	(CVAR = CreateConVar("sm_swgm_shop_bonus_interval",		"60.0",	"Интервал выдавания кредитов.", _, true, 0.0)).AddChangeHook(OnIntervalChange);
	g_fInterval = CVAR.FloatValue;
	
	(CVAR = CreateConVar("sm_swgm_shop_bonus_playing",		"1",	"0 - выдает кредиты всем. 1 - не выдает наблюдателям.", _, true, 0.0, true, 1.0)).AddChangeHook(OnPlayChange);
	g_bPlay = CVAR.BoolValue;
	
	(CVAR = CreateConVar("sm_swgm_shop_bonus_discount",		"0.5",	"Скидка на предметы.")).AddChangeHook(OnDiscChange);
	g_fDisc = CVAR.FloatValue;
	
	LoadTranslations("swgm_shop_bonus.phrases.txt");
	AutoExecConfig(true, "swgm_shop_bonus", "sourcemod/swgm");
}

public void OnTypeChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_bType = convar.BoolValue;
}

public void OnAmountChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_fCredits = convar.FloatValue;
}

public void OnCreditsChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_iCredits = convar.IntValue;
}

public void OnIntervalChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_fInterval = convar.FloatValue;
	
	for(int i = 1; i <= MaxClients; i++) if(SWGM_IsPlayerValidated(i) && SWGM_InGroup(i))
	{
		if(g_hTimer[i])	KillTimer(g_hTimer[i]); g_hTimer[i] = null;
		if(g_fInterval > 0.0)
		{
			g_hTimer[i] = CreateTimer(g_fInterval, Timer_Give, i);
		}
	}
}

public void OnPlayChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_bPlay = convar.BoolValue;
}

public void OnDiscChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_fDisc = CVAR.FloatValue;
}

public void OnClientDisconnect(int iClient)
{
	if(g_hTimer[iClient])	KillTimer(g_hTimer[iClient]); g_hTimer[iClient] = null;
}

public Action Timer_Give(Handle hTimer, int iClient)
{
	if(SWGM_IsPlayerValidated(iClient))
	{
		if(g_bPlay && GetClientTeam(iClient) < 2)
		{
			return Plugin_Continue;
		}
		Shop_GiveClientCredits(iClient, g_iCredits, IGNORE_FORWARD_HOOK);
		PrintToChat(iClient, "%t", "Credits_Give", g_iCredits);
	}
	return Plugin_Continue;
}

public Action Shop_OnCreditsGiven(int iClient, int &iCredits, int iBy_who)
{
	if(SWGM_IsPlayerValidated(iClient) && SWGM_InGroup(iClient) && iBy_who == CREDITS_BY_NATIVE)
	{
		iCredits = g_bType ? iCredits+RoundToCeil(g_fCredits):RoundToCeil(float(iCredits)*g_fCredits);
		return Plugin_Changed;
	}
	return Plugin_Continue;
}

public Action Shop_OnItemBuy(int iClient, CategoryId category_id, const char[] category, ItemId item_id, const char[] item, ItemType type, int &price, int &sell_price, int &value)
{
	if(g_fDisc > 0.0 && SWGM_IsPlayerValidated(iClient) && SWGM_InGroup(iClient))
	{
		price -= RoundToCeil(float(price)*g_fDisc);
		sell_price -= RoundToCeil(float(sell_price)*g_fDisc);
		return Plugin_Changed;
	}
	return Plugin_Continue;
}

public bool Shop_OnItemDisplay(int iClient, ShopMenu menu_action, CategoryId category_id, ItemId item_id, const char[] display, char[] buffer, int maxlength)
{
	if(g_fDisc > 0.0 && SWGM_IsPlayerValidated(iClient) && SWGM_InGroup(iClient))
	{
		FormatEx(buffer, maxlength, "%s (Скидка %i %%)", display, RoundToCeil(g_fDisc*100.0));
		return true;
	}
	return false;
}

public void SWGM_OnJoinGroup(int iClient, bool IsOfficer)
{
	if(g_fInterval > 0.0 && !g_hTimer[iClient]) g_hTimer[iClient] = CreateTimer(g_fInterval, Timer_Give, iClient, TIMER_REPEAT);
}

public void SWGM_OnLeaveGroup(int iClient)
{
	if(g_hTimer[iClient])	KillTimer(g_hTimer[iClient]); g_hTimer[iClient] = null;
}