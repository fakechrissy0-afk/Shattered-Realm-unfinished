extends CharacterBody2D

# --- Variables ---
@export_group("Normal Movement")
@export var SPEED = 300.0
@export var JUMP_VELOCITY = -520.0  
@export var JUMP_CUTOFF = 0.4       
@export var ACCELERATION = 0.15  
@export var FRICTION = 0.25      
@export var AIR_CONTROL = 0.08   

@export_group("Dash Mechanics")
@export var DASH_SPEED = 900.0
@export var DASH_DURATION = 0.15

@export_group("Wall Movement")
@export var WALL_SLIDE_SPEED = 150.0
@export var WALL_JUMP_VELOCITY = Vector2(420.0, -450.0)
@export var WALL_JUMP_LOCK_TIME = 0.22 

# --- Internal Physic Variables ---
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

var is_dashing: bool = false
var dash_timer: float = 0.0
var can_dash: bool = true

var dash_direction: Vector2 = Vector2.ZERO
var last_facing_direction: Vector2 = Vector2.RIGHT
var wall_jump_lock_timer: float = 0.0

# Dead state tracking
var is_dead: bool = false
@onready var respawn_timer: Timer = $RespawnTimer

func _ready() -> void:
	# Connect the timer to the reload function when it finishes counting down
	respawn_timer.timeout.connect(_on_respawn_timer_timeout)

func _physics_process(delta):
	# If the player is dead, completely skip all movement and physics processing
	if is_dead:
		return
		
	# Handle Input Lock Timers
	if wall_jump_lock_timer > 0:
		wall_jump_lock_timer -= delta
	
	# Ground Check
	if is_on_floor() and not is_on_wall() and not is_dashing:
		can_dash = true
		
	# Handle Dash Timer
	if is_dashing:
		dash_timer -= delta
		if dash_timer <= 0:
			is_dashing = false
			if dash_direction.y < 0:
				velocity.y = JUMP_VELOCITY * 0.8 
				
	# Read All Inputs Safely
	var input_dir = Vector2.ZERO
	input_dir.x = Input.get_axis("move_left", "move_right")
	input_dir.y = Input.get_axis("move_up", "move_down")
				
	if input_dir != Vector2.ZERO:
		last_facing_direction = input_dir.normalized()
					
	# Trigger the Dash
	if Input.is_action_just_pressed("dash") and can_dash and not is_dashing:
		is_dashing = true
		dash_timer = DASH_DURATION
		can_dash = false 
						
		if input_dir != Vector2.ZERO:
			dash_direction = input_dir.normalized()
		else:
			dash_direction = last_facing_direction
								
	# Apply Physics
	if is_dashing:
		velocity = dash_direction * DASH_SPEED
	else:
		if not is_on_floor():
			velocity.y += gravity * delta
		
		if is_on_wall() and not is_on_floor() and velocity.y > 0:
			velocity.y = min(velocity.y, WALL_SLIDE_SPEED)
			wall_jump_lock_timer = 0.0
		
		if Input.is_action_just_pressed("jump"):
			if is_on_floor():
				velocity.y = JUMP_VELOCITY
			elif is_on_wall():
				var wall_normal = get_wall_normal().x
				velocity.x = wall_normal * WALL_JUMP_VELOCITY.x
				velocity.y = WALL_JUMP_VELOCITY.y
				wall_jump_lock_timer = WALL_JUMP_LOCK_TIME
		
		if Input.is_action_just_released("jump") and velocity.y < 0:
			velocity.y *= JUMP_CUTOFF
											
		if wall_jump_lock_timer <= 0:
			if input_dir.x != 0:
				var accel_rate = ACCELERATION if is_on_floor() else AIR_CONTROL
				velocity.x = lerp(velocity.x, input_dir.x * SPEED, accel_rate)
			else:
				if is_on_floor():
					velocity.x = lerp(velocity.x, 0.0, FRICTION)
				else:
					velocity.x = lerp(velocity.x, 0.0, AIR_CONTROL)
												
	move_and_slide()

# --- Death Function called by hazards ---
func die():
	if is_dead: return 
	
	is_dead = true
	velocity = Vector2.ZERO 
	
	# 1. Trigger the Particle Burst
	$DeathParticles.emitting = true
	
	# 2. Create a Tween to smoothly shrink the player sprite
	# This shrinks the player to Vector2(0,0) over 0.25 seconds using an Easing curve
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ZERO, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	
	# 3. Start the 0.6 second countdown till level reload
	respawn_timer.start(0.6)

func _on_respawn_timer_timeout():
	# When the 0.6 seconds are up, reload the scene
	get_tree().reload_current_scene()
