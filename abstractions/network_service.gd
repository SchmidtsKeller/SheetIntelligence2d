@abstract class_name NetworkService
extends Node
## Contract for the connection between the two players (GDD §9.4).
##
## An implementation is a transport: WebRTC with QR / text-code pairing in the
## Web build, a localhost transport or an offline loopback for development and
## tests. Everything above it (session, roles, replication) only talks to this
## contract and to Godot's multiplayer API.
##
## The transport installs its [MultiplayerPeer] as the scene tree's multiplayer
## peer as soon as it starts hosting or joining, [b]before[/b] the connection
## exists: the multiplayer API only knows a device whose connection it saw
## being made. When the session ends, the transport puts the offline peer back.
## It reports [signal session_started] once RPCs can reach the other device.
##
## A session always has exactly one host and at most one guest. The host is
## authoritative for the flock, combat and the round state.

## The connection state changed. Emitted before the more specific signals.
@warning_ignore("unused_signal")
signal connection_state_changed(state: ConnectionState)

## The session is established: RPCs reach the other device.
@warning_ignore("unused_signal")
signal session_started

## The session ended, or an attempt to start one failed.
## [param message] is a readable explanation for the player, e.g. a hint about
## Wi-Fi networks that block traffic between devices.
@warning_ignore("unused_signal")
signal session_ended(reason: DisconnectReason, message: String)

## This device produced a pairing code the other device has to read (the
## host's offer or the guest's answer). Only for transports where
## [method requires_pairing_codes] is [code]true[/code].
@warning_ignore("unused_signal")
signal pairing_code_ready(code: String)

enum ConnectionState {
	## No session. The initial state and the state after any failure.
	DISCONNECTED,
	## Hosting or joining was started; the other device is not connected yet.
	CONNECTING,
	## Both devices are connected (or the session is offline).
	CONNECTED,
}

## Why a session ended or could not be established.
enum DisconnectReason {
	NONE,
	## [method close_session] was called on this device.
	LOCAL_CLOSE,
	## The other device closed the session or went away.
	REMOTE_CLOSE,
	## The connection could not be established.
	CONNECTION_FAILED,
	## Establishing the connection took too long.
	TIMED_OUT,
	## A pairing code could not be read or does not belong to this session.
	INVALID_PAIRING_CODE,
}

## Starts a session as the host. [param options] are transport-specific (e.g.
## a port for the localhost transport). Returns [constant OK] when the attempt
## was started; the outcome arrives through the signals.
@abstract func host_session(options: Dictionary = {}) -> Error

## Joins a session as the guest. [param options] are transport-specific (e.g.
## address and port). Returns [constant OK] when the attempt was started.
@abstract func join_session(options: Dictionary = {}) -> Error

## Ends the session or cancels a running attempt. Emits [signal session_ended]
## with [constant DisconnectReason.LOCAL_CLOSE] if there was one.
@abstract func close_session() -> void

## The current connection state.
@abstract func get_connection_state() -> ConnectionState

## Whether this device hosts the session (also [code]true[/code] offline).
@abstract func is_host() -> bool

## Whether the session runs without a second device (sandbox scenes, tests).
@abstract func is_offline() -> bool

## This device's peer id in Godot's multiplayer API; 0 without a session.
@abstract func get_local_peer_id() -> int

## The other device's peer id; 0 while nobody is connected or offline.
@abstract func get_remote_peer_id() -> int

## The peer this transport installed as the scene tree's multiplayer peer;
## [code]null[/code] without a session.
@abstract func get_multiplayer_peer() -> MultiplayerPeer

## Whether the players have to exchange pairing codes to connect
## (serverless WebRTC), as opposed to connecting by address.
@abstract func requires_pairing_codes() -> bool

## Hands over the pairing code shown by the other device: the host's offer on
## the guest, the guest's answer on the host. Returns
## [constant ERR_INVALID_DATA] for a code that cannot be read; the session
## attempt stays alive so the player can try again.
@abstract func submit_pairing_code(code: String) -> Error
