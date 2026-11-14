extends ServiceRegistry
## The autoload [code]Services[/code]: the application's service registry.
##
## On startup it loads the game configuration and registers the default
## implementation of every core contract (see [ServiceBootstrap]), so any
## scene, including a sandbox scene started on its own, finds working services.
##
## The typed accessors are shorthand for [method ServiceRegistry.resolve]:
## [codeblock]
## var speed: float = Services.perks.get_stat(StatIds.HERDER_MOVE_SPEED)
## Services.audio.play_event(AudioEvents.BELL, global_position)
## [/codeblock]

const CONFIG_PATH: String = "res://systems/config/game_config.tres"

## The game configuration: the base values of all gameplay numbers. Read
## effective values through [member perks] instead.
var config: GameConfig

var input: InputService:
	get:
		return resolve(InputService) as InputService

var network: NetworkService:
	get:
		return resolve(NetworkService) as NetworkService

var swarm: SwarmService:
	get:
		return resolve(SwarmService) as SwarmService

var combat: CombatService:
	get:
		return resolve(CombatService) as CombatService

var perks: PerkService:
	get:
		return resolve(PerkService) as PerkService

var audio: AudioService:
	get:
		return resolve(AudioService) as AudioService


func _enter_tree() -> void:
	if config != null:
		return
	config = load(CONFIG_PATH) as GameConfig
	if config == null:
		push_error("Services: could not load the game configuration from %s." % CONFIG_PATH)
		config = GameConfig.new()
	ServiceBootstrap.register_defaults(self, config)
