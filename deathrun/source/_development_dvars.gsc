#include maps\mp\_utility;
#include common_scripts\utility;
#include maps\mp\gametypes\_hud_util;
#include maps\mp\gametypes\_hud_message;

init()
{
    level.DeathRunInProgress = 0;
    level.DeathRunInitialized = 0;
    level.DeathRunIntroDone = 0;
    level.RunnersNum = 0;
    level.LastDeath = "";
    level.Runners = [];

    // Inicializa a posição do percurso antes mesmo dos jogadores spawnarem
    level.DeathRunOrigin = (0, 0, 10000);
    level.DeathRunspawnpoint = level.DeathRunOrigin - (250, 0, 0);
    level.ActivatorSpawn = level.DeathRunspawnpoint + (270, 581, 140);

    precacheShader("white");
    precacheItem("knife_mp");
    precacheItem("usrpg_mp");
    precacheItem("frag_grenade_mp");

    models = array(
        "p6_dockside_container_lrg_orange",
        "collision_clip_wall_128x128x10",
        "collision_clip_wall_512x512x10",
        "collision_clip_wall_256x256x10",
        "t6_wpn_c4_world",
        "com_barrel_biohazard_rust",
        "t6_wpn_supply_drop_axis",
        "t6_wpn_supply_drop_trap",
        "t6_wpn_briefcase_bomb_view",
        "prop_suitcase_bomb",
        "p6_metal_fence_gate",
        "p6_metal_fence"
    );
    for(i = 0; i < models.size; i++)
        precacheModel(models[i]);

    setDvar("scr_tdm_timelimit", "0");
    setDvar("scr_tdm_scorelimit", "0");
    setMatchTalkFlag("EveryoneHearsEveryone", 1);

    level thread onPlayerConnect();
}

onPlayerConnect()
{
    for(;;)
    {
        level waittill("connected", player);
        player thread onPlayerSpawned();
    }
}

onPlayerSpawned()
{
    self endon("disconnect");
    level endon("game_ended");

    for(;;)
    {
        self waittill("spawned_player");

        // 1. Desarmamento imediato para todos (evita tiroteio entre bots)
        self takeAllWeapons();
        self disableWeapons();

        // 2. Se o Host acabou de spawnar, inicia o motor da pista
        if(self isHost() && !isDefined(level.DeathRunEngineStarted))
        {
            level.DeathRunEngineStarted = true;
            level thread GameEngine();
        }

        // 3. Aguarda a pista e a seleção de times inicializarem
        while(!level.DeathRunInitialized)
            wait 0.25;

        // 4. Se o jogador já morreu nesta rodada, vai para a área de espectador no céu
        if(isDefined(self.hasDiedInRun) && self.hasDiedInRun)
        {
            self setOrigin(level.DeathRunspawnpoint + (0, 0, 500));
            self freezeControls(true);
            continue;
        }

        // 5. Configuração do Ativador
        if(isDefined(level.Activator) && self == level.Activator)
        {
            self setOrigin(level.ActivatorSpawn);
            self freezeControls(false);
            self enableInvulnerability();
            self setMoveSpeedScale(1.4);
            self.activator = true;
            self.runner = false;
            self thread maps\mp\gametypes\_hud_message::hintMessage("ACTIVATE TRAPS TO KILL RUNNERS");
        }
        // 6. Configuração dos Runners (inclui bots que entraram atrasados)
        else
        {
            // Teleporta direto para a plataforma inicial dos corredores
            spawnPos = level.DeathRunspawnpoint + (randomIntRange(-120, 120), randomIntRange(-60, 60), 150);
            self setOrigin(spawnPos);
            self freezeControls(false);

            if(!isDefined(self.isRegisteredRunner) || !self.isRegisteredRunner)
            {
                self.isRegisteredRunner = true;
                self.runner = true;
                self.activator = false;
                level.Runners[level.Runners.size] = self;
                level.RunnersNum++;
            }

            self thread maps\mp\gametypes\_hud_message::hintMessage("SURVIVE THE DEATH RUN");
        }

        self.deathRunStarted = true;
        self thread DeathBarrierMonitor();
        self thread PlayerDeathWatcher();
    }
}

// =========================================================================
// MONITOR DE MORTE & PREVENÇÃO DE CONTADOR NEGATIVO
// =========================================================================

PlayerDeathWatcher()
{
    self endon("disconnect");
    self waittill("death");

    // Ignora mortes do Ativador
    if(isDefined(level.Activator) && self == level.Activator)
        return;

    // Só decrementa se o jogador era um Runner ativo (evita contagem negativa)
    if(isDefined(self.runner) && self.runner)
    {
        self.runner = false;
        self.hasDiedInRun = true;

        if(level.RunnersNum > 0)
            level.RunnersNum--;

        level.LastDeath = self.name;
        level notify("DeathNotification");
    }

    // Condição de vitória do Ativador (quando todos os Runners registrados morrerem)
    if(level.DeathRunInProgress && level.RunnersNum == 0 && level.players.size > 1)
    {
        iPrintlnBold("^1ACTIVATOR WON! ALL RUNNERS ELIMINATED!");
        wait 2.0;
        maps\mp\gametypes\_globallogic::forceEnd(0);
    }
}

// Só pune queda caso o jogador realmente caia da pista lá no céu
DeathBarrierMonitor()
{
    self endon("disconnect");
    self endon("death");

    // Aguarda o jogador estar na altitude da pista
    while(self.origin[2] < 9500)
        wait 0.2;

    while(isAlive(self))
    {
        wait 0.25;
        if(self.origin[2] < 9000)
        {
            self doDamage(9999, self.origin, level.Activator, level.Activator, "none", "MOD_FALLING", 0, "none");
            break;
        }
    }
}

// =========================================================================
// ENGINE DE PARTIDA & SELEÇÃO DE TIMES
// =========================================================================

GameEngine()
{
    maps\mp\_ambientpackage::MapInit();

    // Cria a plataforma invisível/sólida para os eliminados assistirem
    maps\mp\_ambientpackage::modelSpawner(level.DeathRunspawnpoint + (0, 0, 480), "p6_dockside_container_lrg_orange");

    level.DeathRunInitialized = true;
    level thread DeathRun_Notifications();

    GameIntro();

    TeamInit();
    maps\mp\_ambientpackage::BuildTraps();
    SpawnAllCurrentPlayers();

    wait 3.0;
    maps\mp\_ambientpackage::OpenGates();
}

GameIntro()
{
    introScreen = newHudElem();
    introScreen.x = 0;
    introScreen.y = 0;
    introScreen.alignX = "center";
    introScreen.alignY = "middle";
    introScreen.horzAlign = "center";
    introScreen.vertAlign = "middle";
    introScreen setShader("white", 900, 600);
    introScreen.color = (0, 0, 0);
    introScreen.alpha = 0.85;

    title = createServerFontString("bigfixed", 1.8);
    title setPoint("TOP", "TOP", 0, 60);
    title setText("WELCOME TO DEATH RUN");
    title.color = (0.2, 0.9, 0.4);

    desc = createServerFontString("objective", 1.3);
    desc setPoint("TOP", "TOP", 0, 110);
    desc setText("1 Activator controls the deadly traps. Runners must dodge and survive!");
    desc.color = (1, 1, 1);

    desc2 = createServerFontString("objective", 1.2);
    desc2 setPoint("TOP", "TOP", 0, 140);
    desc2 setText("Reach the end to confront the Activator in close quarters combat.");
    desc2.color = (0.8, 0.8, 0.8);

    wait 4.5;

    introScreen fadeOverTime(1.0);
    introScreen.alpha = 0;
    title fadeOverTime(1.0);
    title.alpha = 0;
    desc fadeOverTime(1.0);
    desc.alpha = 0;
    desc2 fadeOverTime(1.0);
    desc2.alpha = 0;

    wait 1.0;
    introScreen destroy();
    title destroy();
    desc destroy();
    desc2 destroy();

    level.DeathRunIntroDone = true;
}

TeamInit()
{
    while(level.players.size == 0)
        wait 0.25;

    // Modo solo (para testes locais)
    if(level.players.size == 1)
    {
        level.Activator = level.players[0];
        level.Runners = array(level.players[0]);
        level.players[0].runner = true;
        level.players[0].activator = true;
        level.RunnersNum = 1;
        return;
    }

    // Com 2 ou mais jogadores/bots:
    level.Runners = [];
    foreach(p in level.players)
        level.Runners[level.Runners.size] = p;

    // Sorteia o Ativador
    index = randomInt(level.Runners.size);
    level.Activator = level.Runners[index];

    // Remove o ativador da lista de corredores
    newList = [];
    foreach(r in level.Runners)
    {
        if(r != level.Activator)
            newList[newList.size] = r;
    }
    level.Runners = newList;

    foreach(runner in level.Runners)
    {
        runner.runner = true;
        runner.activator = false;
        runner.isRegisteredRunner = true;
    }

    level.Activator.activator = true;
    level.Activator.runner = false;
    level.RunnersNum = level.Runners.size;
}

SpawnAllCurrentPlayers()
{
    for(i = 0; i < level.Runners.size; i++)
    {
        runner = level.Runners[i];
        if(isDefined(runner) && isAlive(runner))
        {
            spawnPos = level.DeathRunspawnpoint + (randomIntRange(-120, 120), randomIntRange(-60, 60), 150);
            runner setOrigin(spawnPos);
            runner freezeControls(false);
            runner takeAllWeapons();
            runner disableWeapons();
        }
    }

    if(isDefined(level.Activator) && level.players.size > 1)
    {
        level.Activator setOrigin(level.ActivatorSpawn);
        level.Activator freezeControls(false);
        level.Activator enableInvulnerability();
        level.Activator setMoveSpeedScale(1.4);
        level.Activator takeAllWeapons();
        level.Activator disableWeapons();
    }

    level.DeathRunInProgress = 1;
}

// =========================================================================
// NOTIFICAÇÕES DE MORTE NO HUD
// =========================================================================

DeathRun_Notifications()
{
    notifyText = createServerFontString("objective", 1.25);
    notifyText setPoint("TOP RIGHT", "TOP RIGHT", -20, 20);
    notifyText.glowAlpha = 1.0;
    notifyText.glowColor = (0, 0, 0);
    notifyText.alpha = 0;

    for(;;)
    {
        level waittill("DeathNotification");
        notifyText setText("^1" + level.LastDeath + " ^7was eliminated! (^2" + level.RunnersNum + " ^7Runners remaining)");
        notifyText.alpha = 1;
        wait 3.5;
        notifyText fadeOverTime(1.0);
        notifyText.alpha = 0;
    }
}