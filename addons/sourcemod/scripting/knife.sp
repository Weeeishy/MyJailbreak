//includes
#include <cstrike>
#include <sourcemod>
#include <sdktools>
#include <smartjaildoors>
#include <wardn>
#include <colors>
#include <sdkhooks>
#include <autoexecconfig>
#include <myjailbreak>

//Compiler Options
#pragma semicolon 1
#pragma newdecls required

//Booleans
bool IsKnifeFight = false; 
bool StartKnifeFight = false; 

//ConVars
ConVar gc_bPlugin;
ConVar gc_bTag;
ConVar gc_bSetW;
ConVar gc_bGrav;
ConVar gc_fGravValue;
ConVar gc_bIce;
ConVar gc_bThirdPerson;
ConVar gc_fIceValue;
ConVar gc_iCooldownStart;
ConVar gc_bSetA;
ConVar gc_bVote;
ConVar gc_iCooldownDay;
ConVar gc_iRoundTime;
ConVar gc_iTruceTime;
ConVar gc_bOverlays;
ConVar gc_sOverlayStartPath;
ConVar g_iSetRoundTime;
ConVar g_bAllowTP;

//Integers
int g_iOldRoundTime;
int g_iCoolDown;
int g_iTruceTime;
int g_iVoteCount = 0;
int KnifeFightRound = 0;

//Handles
Handle TruceTimer;
Handle KnifeFightMenu;

//Strings
char g_sHasVoted[1500];

public Plugin myinfo = {
	name = "MyJailbreak - KnifeFight",
	author = "shanapu & Floody.de, Franc1sco",
	description = "Jailbreak KnifeFight script",
	version = PLUGIN_VERSION,
	url = ""
};

public void OnPluginStart()
{
	// Translation
	LoadTranslations("MyJailbreakWarden.phrases");
	LoadTranslations("MyJailbreakKnifeFight.phrases");
	
	//Client Commands
	RegConsoleCmd("sm_setknifefight", SetKnifeFight);
	RegConsoleCmd("sm_knifefight", VoteKnifeFight);
	
	//AutoExecConfig
	AutoExecConfig_SetFile("MyJailbreak_knifefight");
	AutoExecConfig_SetCreateFile(true);
	
	AutoExecConfig_CreateConVar("sm_knifefight_version", PLUGIN_VERSION, "The version of the SourceMod plugin MyJailBreak - knifefight", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	gc_bPlugin = AutoExecConfig_CreateConVar("sm_knifefight_enable", "1", "0 - disabled, 1 - enable knifefight");
	gc_bSetW = AutoExecConfig_CreateConVar("sm_knifefight_warden", "1", "0 - disabled, 1 - allow warden to set knifefight round", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	gc_bSetA = AutoExecConfig_CreateConVar("sm_knifefight_admin", "1", "0 - disabled, 1 - allow admin to set knifefight round", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	gc_bVote = AutoExecConfig_CreateConVar("sm_knifefight_vote", "1", "0 - disabled, 1 - allow player to vote for knifefight", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	gc_bThirdPerson = AutoExecConfig_CreateConVar("sm_knifefight_Thirdperson", "1", "0 - disabled, 1 - enable third person for knifefight", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	gc_bGrav = AutoExecConfig_CreateConVar("sm_knifefight_gravity", "1", "0 - disabled, 1 - enable low Gravity for knifefight", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	gc_fGravValue= AutoExecConfig_CreateConVar("sm_knifefight_gravity_value", "0.3","Ratio for Gravity 1.0 earth 0.5 moon", 0, true, 0.1, true, 1.0);
	gc_bIce = AutoExecConfig_CreateConVar("sm_knifefight_gravity", "1", "0 - disabled, 1 - enable low Gravity for knifefight", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	gc_fIceValue= AutoExecConfig_CreateConVar("sm_knifefight_gravity_value", "1.0","Ratio iceskate (5.2 normal)", 0, true, 0.5, true, 5.2);
	gc_iRoundTime = AutoExecConfig_CreateConVar("sm_knifefight_roundtime", "5", "Round time for a single knifefight round");
	gc_iTruceTime = AutoExecConfig_CreateConVar("sm_knifefight_trucetime", "15", "Time for no damage");
	gc_iCooldownDay = AutoExecConfig_CreateConVar("sm_knifefight_cooldown_day", "3", "Rounds cooldown after a event until this event can startet");
	gc_iCooldownStart = AutoExecConfig_CreateConVar("sm_knifefight_cooldown_start", "3", "Rounds until event can be started after mapchange.", FCVAR_NOTIFY, true, 0.0, true, 255.0);
	gc_bOverlays = AutoExecConfig_CreateConVar("sm_knifefight_overlays", "1", "0 - disabled, 1 - enable overlays", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	gc_sOverlayStartPath = AutoExecConfig_CreateConVar("sm_knifefight_overlaystart_path", "overlays/MyJailbreak/start" , "Path to the start Overlay DONT TYPE .vmt or .vft");
	gc_bTag = AutoExecConfig_CreateConVar("sm_knifefight_tag", "1", "Allow \"MyJailbreak\" to be added to the server tags? So player will find servers with MyJB faster", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	
	AutoExecConfig_ExecuteFile();
	AutoExecConfig_CleanFile();
	
	//Hooks
	HookEvent("round_start", RoundStart);
	HookConVarChange(gc_sOverlayStartPath, OnSettingChanged);
	HookEvent("round_end", RoundEnd);
	
	//Find
	g_bAllowTP = FindConVar("sv_allow_thirdperson");
	g_iSetRoundTime = FindConVar("mp_roundtime");
	g_iCoolDown = gc_iCooldownDay.IntValue + 1;
	g_iTruceTime = gc_iTruceTime.IntValue;
	gc_sOverlayStartPath.GetString(g_sOverlayStart , sizeof(g_sOverlayStart));
	
	if(g_bAllowTP == INVALID_HANDLE)
	{
		SetFailState("sv_allow_thirdperson not found!");
	}
	
	IsKnifeFight = false;
	StartKnifeFight = false;
	g_iVoteCount = 0;
	KnifeFightRound = 0;
}

public int OnSettingChanged(Handle convar, const char[] oldValue, const char[] newValue)
{
	if(convar == gc_sOverlayStartPath)
	{
		strcopy(g_sOverlayStart, sizeof(g_sOverlayStart), newValue);
		if(gc_bOverlays.BoolValue) PrecacheOverlayAnyDownload(g_sOverlayStart);
	}
}

public void OnMapStart()
{
	if(gc_bOverlays.BoolValue) PrecacheOverlayAnyDownload(g_sOverlayStart);
	g_iVoteCount = 0;
	KnifeFightRound = 0;
	IsKnifeFight = false;
	StartKnifeFight = false;
	g_iCoolDown = gc_iCooldownStart.IntValue + 1;
	g_iTruceTime = gc_iTruceTime.IntValue;
}

public void OnConfigsExecuted()
{
	g_iTruceTime = gc_iTruceTime.IntValue;
	g_iCoolDown = gc_iCooldownStart.IntValue + 1;
	
	if (gc_bTag.BoolValue)
	{
		ConVar hTags = FindConVar("sv_tags");
		char sTags[128];
		hTags.GetString(sTags, sizeof(sTags));
		if (StrContains(sTags, "MyJailbreak", false) == -1)
		{
			StrCat(sTags, sizeof(sTags), ", MyJailbreak");
			hTags.SetString(sTags);
		}
	}
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_WeaponCanUse, OnWeaponCanUse);
}

public Action SetKnifeFight(int client,int args)
{
	if (gc_bPlugin.BoolValue)
	{
		if (warden_iswarden(client))
		{
			if (gc_bSetW.BoolValue)
			{
				char EventDay[64];
				GetEventDay(EventDay);
				
				if(StrEqual(EventDay, "none", false))
				{
					if (g_iCoolDown == 0)
					{
						StartNextRound();
					}
					else CPrintToChat(client, "%t %t", "knifefight_tag" , "knifefight_wait", g_iCoolDown);
				}
				else CPrintToChat(client, "%t %t", "knifefight_tag" , "knifefight_progress" , EventDay);
			}
			else CPrintToChat(client, "%t %t", "warden_tag" , "nocscope_setbywarden");
		}
		else if (CheckCommandAccess(client, "sm_map", ADMFLAG_CHANGEMAP, true))
			{
				if (gc_bSetA.BoolValue)
				{
					char EventDay[64];
					GetEventDay(EventDay);
					
					if(StrEqual(EventDay, "none", false))
					{
						if (g_iCoolDown == 0)
						{
							StartNextRound();
						}
						else CPrintToChat(client, "%t %t", "knifefight_tag" , "knifefight_wait", g_iCoolDown);
					}
					else CPrintToChat(client, "%t %t", "knifefight_tag" , "knifefight_progress" , EventDay);
				}
				else CPrintToChat(client, "%t %t", "nocscope_tag" , "knifefight_setbyadmin");
			}
			else CPrintToChat(client, "%t %t", "warden_tag" , "warden_notwarden");
	}
	else CPrintToChat(client, "%t %t", "knifefight_tag" , "knifefight_disabled");
}

public Action VoteKnifeFight(int client,int args)
{
	char steamid[64];
	GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid));
	
	if (gc_bPlugin.BoolValue)
	{
		if (gc_bVote.BoolValue)
		{
			char EventDay[64];
			GetEventDay(EventDay);
			
			if(StrEqual(EventDay, "none", false))
			{
				if (g_iCoolDown == 0)
				{
					if (StrContains(g_sHasVoted, steamid, true) == -1)
					{
						int playercount = (GetClientCount(true) / 2);
						g_iVoteCount++;
						int Missing = playercount - g_iVoteCount + 1;
						Format(g_sHasVoted, sizeof(g_sHasVoted), "%s,%s", g_sHasVoted, steamid);
						
						if (g_iVoteCount > playercount)
						{
							StartNextRound();
						}
						else CPrintToChatAll("%t %t", "knifefight_tag" , "knifefight_need", Missing, client);
					}
					else CPrintToChat(client, "%t %t", "knifefight_tag" , "knifefight_voted");
				}
				else CPrintToChat(client, "%t %t", "knifefight_tag" , "knifefight_wait", g_iCoolDown);
			}
			else CPrintToChat(client, "%t %t", "knifefight_tag" , "knifefight_progress" , EventDay);
		}
		else CPrintToChat(client, "%t %t", "knifefight_tag" , "knifefight_voting");
	}
	else CPrintToChat(client, "%t %t", "knifefight_tag" , "knifefight_disabled");
}

void StartNextRound()
{
	StartKnifeFight = true;
	g_iCoolDown = gc_iCooldownDay.IntValue + 1;
	g_iVoteCount = 0;
	
	SetEventDay("knifefight");
	
	CPrintToChatAll("%t %t", "knifefight_tag" , "knifefight_next");
	PrintHintTextToAll("%t", "knifefight_next_nc");

}

public void RoundStart(Handle event, char[] name, bool dontBroadcast)
{
	if (StartKnifeFight)
	{
		char info1[255], info2[255], info3[255], info4[255], info5[255], info6[255], info7[255], info8[255];
		ServerCommand("sm_removewarden");
		SetCvar("sm_hosties_lr", 0);
		SetCvar("sm_weapons_enable", 0);
		SetCvar("sm_warden_enable", 0);
		SetConVarInt(g_bAllowTP, 1);
		IsKnifeFight = true;
		
		KnifeFightRound++;
		StartKnifeFight = false;
		SJD_OpenDoors();
		KnifeFightMenu = CreatePanel();
		Format(info1, sizeof(info1), "%T", "knifefight_info_Title", LANG_SERVER);
		SetPanelTitle(KnifeFightMenu, info1);
		DrawPanelText(KnifeFightMenu, "                                   ");
		Format(info2, sizeof(info2), "%T", "knifefight_info_Line1", LANG_SERVER);
		DrawPanelText(KnifeFightMenu, info2);
		DrawPanelText(KnifeFightMenu, "-----------------------------------");
		Format(info3, sizeof(info3), "%T", "knifefight_info_Line2", LANG_SERVER);
		DrawPanelText(KnifeFightMenu, info3);
		Format(info4, sizeof(info4), "%T", "knifefight_info_Line3", LANG_SERVER);
		DrawPanelText(KnifeFightMenu, info4);
		Format(info5, sizeof(info5), "%T", "knifefight_info_Line4", LANG_SERVER);
		DrawPanelText(KnifeFightMenu, info5);
		Format(info6, sizeof(info6), "%T", "knifefight_info_Line5", LANG_SERVER);
		DrawPanelText(KnifeFightMenu, info6);
		Format(info7, sizeof(info7), "%T", "knifefight_info_Line6", LANG_SERVER);
		DrawPanelText(KnifeFightMenu, info7);
		Format(info8, sizeof(info8), "%T", "knifefight_info_Line7", LANG_SERVER);
		DrawPanelText(KnifeFightMenu, info8);
		DrawPanelText(KnifeFightMenu, "-----------------------------------");
		
		if (KnifeFightRound > 0)
			{
				for(int client=1; client <= MaxClients; client++)
				{
					if (IsClientInGame(client))
					{
						if (gc_bGrav.BoolValue)
						{
							SetEntityGravity(client, gc_fGravValue.FloatValue);
						}
						if (gc_bIce.BoolValue)
						{
							SetCvarFloat("sv_friction", gc_fIceValue.FloatValue);
						}
						if (gc_bThirdPerson.BoolValue)
						{
							ClientCommand(client, "thirdperson");
						}
						SendPanelToClient(KnifeFightMenu, client, Pass, 15);
						SetEntProp(client, Prop_Data, "m_takedamage", 0, 1);
						StripAllWeapons(client);
						GivePlayerItem(client, "weapon_knife");
						if (GetClientTeam(client) == CS_TEAM_CT)
						{
							SetEntityHealth(client, 45);
						}
						if (GetClientTeam(client) == CS_TEAM_T)
						{
							SetEntityHealth(client, 15);
						}
					}
				}
				g_iTruceTime--;
				TruceTimer = CreateTimer(1.0, KnifeFight, _, TIMER_REPEAT);
			}
	}
	else
	{
		char EventDay[64];
		GetEventDay(EventDay);
		
		if(!StrEqual(EventDay, "none", false))
		{
			g_iCoolDown = gc_iCooldownDay.IntValue + 1;
		}
		else if (g_iCoolDown > 0) g_iCoolDown--;
	}
}

public Action OnWeaponCanUse(int client, int weapon)
{
	if(IsKnifeFight == true)
	{
		char sWeapon[32];
		GetEdictClassname(weapon, sWeapon, sizeof(sWeapon));
		if(StrEqual(sWeapon, "weapon_knife"))
		{
			if (IsClientInGame(client) && IsPlayerAlive(client))
			{
				return Plugin_Continue;
			}
		}
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public Action KnifeFight(Handle timer)
{
	if (g_iTruceTime > 1)
	{
		g_iTruceTime--;
		for (int client=1; client <= MaxClients; client++)
		if (IsClientInGame(client) && IsPlayerAlive(client))
			{
				PrintCenterText(client,"%t", "knifefight_timetounfreeze_nc", g_iTruceTime);
			}
		return Plugin_Continue;
	}
	
	g_iTruceTime = gc_iTruceTime.IntValue;
	
	if (KnifeFightRound > 0)
	{
		for (int client=1; client <= MaxClients; client++)
		{
			if (IsClientInGame(client) && IsPlayerAlive(client))
			{
				SetEntProp(client, Prop_Data, "m_takedamage", 2, 1);
				if (gc_bGrav.BoolValue)
				{
					SetEntityGravity(client, gc_fGravValue.FloatValue);	
				}
			}
			CreateTimer( 0.0, ShowOverlayStart, client);
			
		}
	}
	PrintHintTextToAll("%t", "knifefight_start_nc");
	CPrintToChatAll("%t %t", "knifefight_tag" , "knifefight_start");
	
	TruceTimer = null;
	
	return Plugin_Stop;
}

public void RoundEnd(Handle event, char[] name, bool dontBroadcast)
{
	int winner = GetEventInt(event, "winner");
	
	if (IsKnifeFight)
	{
		for(int client=1; client <= MaxClients; client++)
		{
			if (IsClientInGame(client))
			{
				SetEntityGravity(client, 1.0);
				FP(client);
			}
		}
		
		if (TruceTimer != null) KillTimer(TruceTimer);
		if (winner == 2) PrintHintTextToAll("%t", "knifefight_twin_nc");
		if (winner == 3) PrintHintTextToAll("%t", "knifefight_ctwin_nc");
		IsKnifeFight = false;
		StartKnifeFight = false;
		KnifeFightRound = 0;
		Format(g_sHasVoted, sizeof(g_sHasVoted), "");
		SetCvar("sm_hosties_lr", 1);
		SetCvar("sm_weapons_enable", 1);
		SetCvar("sm_warden_enable", 1);
		SetCvarFloat("sv_friction", 5.2);
		SetConVarInt(g_bAllowTP, 0);
		
		g_iSetRoundTime.IntValue = g_iOldRoundTime;
		SetEventDay("none");
		CPrintToChatAll("%t %t", "knifefight_tag" , "knifefight_end");
	}
	if (StartKnifeFight)
	{
		g_iOldRoundTime = g_iSetRoundTime.IntValue;
		g_iSetRoundTime.IntValue = gc_iRoundTime.IntValue;
	}
}

public Action FP(int client)
{
	ClientCommand(client, "firstperson");
}

public void OnMapEnd()
{
	IsKnifeFight = false;
	StartKnifeFight = false;
	g_iVoteCount = 0;
	KnifeFightRound = 0;
	g_sHasVoted[0] = '\0';
	SetEventDay("none");
}