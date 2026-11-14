class_name PairingCode
extends RefCounted
## The text two devices exchange to connect without a server (GDD §9.4): the
## host's offer or the guest's answer, as a QR code or as text.
##
## A code carries one WebRTC session description with all of its ICE
## candidates, so one code per direction is enough. The text is Base32
## (A-Z, 2-7): every character is in the QR code's alphanumeric mode, and it
## survives messenger apps, which may change case or break long lines.
##
## Layout before Base32: format version, kind, session id (4 bytes), checksum
## (4 bytes), then the description compressed with Deflate. The session id is
## the host's: an answer must carry the id of the host's offer.

## What is wrong with a code that cannot be used.
enum Problem {
	NONE,
	## Not a pairing code at all, or empty.
	NOT_A_CODE,
	## Cut off or changed on the way.
	DAMAGED,
	## Made by another version of the game.
	OTHER_VERSION,
	## An offer where an answer is expected, or the other way round.
	WRONG_KIND,
	## An answer to another host's offer.
	OTHER_SESSION,
}

## Which side made the code.
enum Kind {
	## The host's offer, read by the guest.
	OFFER,
	## The guest's answer, read by the host.
	ANSWER,
}

## Bump when the layout changes; older and newer games then refuse each
## other's codes with a clear message.
const FORMAT_VERSION: int = 1
const ALPHABET: String = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"
const HEADER_SIZE: int = 10
## Session lines a data channel does without (they concern audio and video).
const SKIPPED_LINES: PackedStringArray = ["a=extmap-allow-mixed", "a=msid-semantic"]
## The largest description a code may unpack to.
const MAX_DESCRIPTION_BYTES: int = 65536

var kind: Kind = Kind.OFFER
var session_id: int = 0
## The session description in SDP, candidates included, with CRLF line ends.
var description: String = ""
var problem: Problem = Problem.NONE


## Makes the text of a code.
static func encode(code_kind: Kind, code_session_id: int, sdp: String) -> String:
	# CRLF is restored when decoding; LF alone packs smaller.
	var packed: PackedByteArray = sdp.replace("\r\n", "\n").to_utf8_buffer().compress(
		FileAccess.COMPRESSION_DEFLATE
	)
	var head: PackedByteArray = PackedByteArray([FORMAT_VERSION, code_kind])
	head.append_array(_int32_to_bytes(code_session_id))
	var checked: PackedByteArray = head.duplicate()
	checked.append_array(packed)
	var data: PackedByteArray = head
	data.append_array(_checksum(checked))
	data.append_array(packed)
	return to_base32(data)


## Reads [param text]. The result's [member problem] says whether it can be
## used; whitespace, dashes and lower case are accepted.
static func decode(text: String) -> PairingCode:
	var code: PairingCode = PairingCode.new()
	var cleaned: String = text.to_upper()
	for separator: String in [" ", "-", "\n", "\r", "\t"]:
		cleaned = cleaned.replace(separator, "")
	var data: PackedByteArray = from_base32(cleaned)
	if data.is_empty():
		code.problem = Problem.NOT_A_CODE
		return code
	if data[0] != FORMAT_VERSION:
		code.problem = Problem.OTHER_VERSION
		return code
	if data.size() <= HEADER_SIZE or data[1] > Kind.ANSWER:
		code.problem = Problem.DAMAGED
		return code
	var checked: PackedByteArray = data.slice(0, 6)
	checked.append_array(data.slice(HEADER_SIZE))
	if _checksum(checked) != data.slice(6, HEADER_SIZE):
		code.problem = Problem.DAMAGED
		return code
	var unpacked: PackedByteArray = data.slice(HEADER_SIZE).decompress_dynamic(
		MAX_DESCRIPTION_BYTES, FileAccess.COMPRESSION_DEFLATE
	)
	if unpacked.is_empty():
		code.problem = Problem.DAMAGED
		return code
	code.kind = data[1] as Kind
	code.session_id = data.decode_u32(2)
	code.description = unpacked.get_string_from_utf8().replace("\n", "\r\n")
	return code


## Like [method decode], but also checks that the code is of [param expected]
## kind and, for an answer, belongs to [param expected_session_id].
static func decode_expected(text: String, expected: Kind, expected_session_id: int) -> PairingCode:
	var code: PairingCode = decode(text)
	if code.problem != Problem.NONE:
		return code
	if code.kind != expected:
		code.problem = Problem.WRONG_KIND
	elif expected == Kind.ANSWER and code.session_id != expected_session_id:
		code.problem = Problem.OTHER_SESSION
	return code


## Writes [param candidates] into [param sdp] as [code]a=candidate[/code]
## lines of their media sections, so the other device needs nothing else.
## Each candidate is [code][media_id, section_index, candidate][/code], as
## [signal WebRTCPeerConnection.ice_candidate_created] reports it.
## [br]To keep the code small, it leaves out what a data channel in the local
## network does not need: TCP candidates (the browser only makes active ones,
## which cannot meet), the optional extensions at the end of each candidate,
## and the [constant SKIPPED_LINES].
static func with_candidates(sdp: String, candidates: Array) -> String:
	var lines: PackedStringArray = sdp.strip_edges().split("\r\n")
	var sections: Array[PackedStringArray] = [PackedStringArray()]
	for line: String in lines:
		if line.begins_with("m="):
			sections.append(PackedStringArray())
		if not _is_skipped(line):
			sections[-1].append(line)
	for candidate: Array in candidates:
		var index: int = candidate[1] + 1
		var line: String = _short_candidate(String(candidate[2]))
		if index >= sections.size() or line.is_empty():
			continue
		sections[index].append(line)
	for index: int in range(1, sections.size()):
		sections[index].append("a=end-of-candidates")
	var result: PackedStringArray = []
	for section: PackedStringArray in sections:
		result.append_array(section)
	return "\r\n".join(result) + "\r\n"


## A readable explanation of [param code_problem] for the player.
static func describe(code_problem: Problem) -> String:
	match code_problem:
		Problem.NOT_A_CODE:
			return "This is not a pairing code."
		Problem.DAMAGED:
			return "The code is incomplete or damaged. Copy or scan it again."
		Problem.OTHER_VERSION:
			return "The code comes from another version of the game. Update both devices."
		Problem.WRONG_KIND:
			return "Wrong code: the host scans the guest's answer, the guest the host's code."
		Problem.OTHER_SESSION:
			return "This answer belongs to another host's code. Start over on the guest."
		_:
			return ""


## Base32 (RFC 4648) without padding.
static func to_base32(data: PackedByteArray) -> String:
	var text: PackedStringArray = []
	var buffer: int = 0
	var bits: int = 0
	for byte: int in data:
		buffer = ((buffer << 8) | byte) & 0xFFF
		bits += 8
		while bits >= 5:
			bits -= 5
			text.append(ALPHABET[(buffer >> bits) & 31])
	if bits > 0:
		text.append(ALPHABET[(buffer << (5 - bits)) & 31])
	return "".join(text)


## Reads Base32 written by [method to_base32]; empty for any other character.
static func from_base32(text: String) -> PackedByteArray:
	var data: PackedByteArray = []
	var buffer: int = 0
	var bits: int = 0
	for character: String in text:
		var value: int = ALPHABET.find(character)
		if value < 0:
			return PackedByteArray()
		buffer = ((buffer << 5) | value) & 0xFFF
		bits += 5
		if bits >= 8:
			bits -= 8
			data.append((buffer >> bits) & 0xFF)
	return data


static func _is_skipped(line: String) -> bool:
	for skipped: String in SKIPPED_LINES:
		if line.begins_with(skipped):
			return true
	return false


## [param candidate] as an [code]a=candidate[/code] line up to its type
## (RFC 8839: the rest is optional); empty for a TCP candidate.
static func _short_candidate(candidate: String) -> String:
	var line: String = candidate if candidate.begins_with("a=") else "a=" + candidate
	var fields: PackedStringArray = line.split(" ")
	# foundation component transport priority address port "typ" type
	if fields.size() < 8 or fields[6] != "typ":
		return line
	if fields[2].to_lower() == "tcp":
		return ""
	return " ".join(fields.slice(0, 8))


static func _checksum(data: PackedByteArray) -> PackedByteArray:
	var hashing: HashingContext = HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(data)
	return hashing.finish().slice(0, 4)


static func _int32_to_bytes(value: int) -> PackedByteArray:
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(4)
	bytes.encode_u32(0, value)
	return bytes
