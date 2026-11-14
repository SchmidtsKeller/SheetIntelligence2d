extends TestCase
## Pairing codes (GDD §9.4): what goes in comes out, and every damaged,
## foreign or outdated code is refused with a reason.

## A data-channel offer as Chrome makes it, before its candidates.
const OFFER_SDP: String = (
	"v=0\r\no=- 4611731400430051336 2 IN IP4 127.0.0.1\r\ns=-\r\nt=0 0\r\n"
	+ "a=group:BUNDLE 0\r\na=extmap-allow-mixed\r\na=msid-semantic: WMS\r\n"
	+ "m=application 9 UDP/DTLS/SCTP webrtc-datachannel\r\nc=IN IP4 0.0.0.0\r\n"
	+ "a=ice-ufrag:Kq3e\r\na=ice-pwd:9yB3l6nLbQ8wqz0lUfQvJ0nC\r\na=ice-options:trickle\r\n"
	+ "a=fingerprint:sha-256 4F:2A:91:0C:7B:E3:55:18:6D:AF:30:C2:9E:41:77:B8:"
	+ "05:DA:6E:13:F0:82:4C:99:A1:3B:5E:07:C8:D4:21:6F\r\n"
	+ "a=setup:actpass\r\na=mid:0\r\na=sctp-port:5000\r\na=max-message-size:262144\r\n"
)
const CANDIDATE: String = (
	"candidate:1840965416 1 udp 2113937151 0b7c1a3e-6f52-4d2b-9c1e-3a0d6f8e2b41.local"
	+ " 54321 typ host generation 0 network-cost 999"
)
## [constant CANDIDATE] without its optional extensions.
const SHORT_CANDIDATE: String = (
	"a=candidate:1840965416 1 udp 2113937151 0b7c1a3e-6f52-4d2b-9c1e-3a0d6f8e2b41.local"
	+ " 54321 typ host"
)
const TCP_CANDIDATE: String = (
	"candidate:977725298 1 tcp 1518214911 172.30.0.2 9 typ host" + " tcptype active generation 0"
)
const SESSION: int = 0xC0FFEE42

# --- Round trip ------------------------------------------------------------------


func test_a_code_brings_the_description_across_unchanged() -> void:
	var sdp: String = PairingCode.with_candidates(OFFER_SDP, [["0", 0, CANDIDATE]])
	var text: String = PairingCode.encode(PairingCode.Kind.OFFER, SESSION, sdp)

	var code: PairingCode = PairingCode.decode(text)

	assert_eq(code.problem, PairingCode.Problem.NONE)
	assert_eq(code.kind, PairingCode.Kind.OFFER)
	assert_eq(code.session_id, SESSION)
	assert_eq(code.description, sdp, "CRLF line ends and every character survive")


func test_a_code_uses_only_characters_of_the_qr_alphanumeric_mode() -> void:
	var text: String = PairingCode.encode(PairingCode.Kind.ANSWER, SESSION, OFFER_SDP)
	var allowed: String = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ $%*+-./:"
	for character: String in text:
		assert_true(allowed.contains(character), "'%s' fits a QR code" % character)


func test_a_code_survives_messengers() -> void:
	var text: String = PairingCode.encode(PairingCode.Kind.OFFER, SESSION, OFFER_SDP)
	var mangled: String = "  " + text.substr(0, 40).to_lower() + "\n" + text.substr(40) + " \r\n"
	var grouped: String = "-".join(_groups(text, 5))

	assert_eq(PairingCode.decode(mangled).description, OFFER_SDP, "case and line breaks")
	assert_eq(PairingCode.decode(grouped).description, OFFER_SDP, "dashes between groups")


func test_base32_follows_rfc_4648_without_padding() -> void:
	# RFC 4648, section 10.
	var vectors: Dictionary = {
		"": "",
		"f": "MY",
		"fo": "MZXQ",
		"foo": "MZXW6",
		"foob": "MZXW6YQ",
		"fooba": "MZXW6YTB",
		"foobar": "MZXW6YTBOI",
	}
	for plain: String in vectors:
		assert_eq(PairingCode.to_base32(plain.to_utf8_buffer()), vectors[plain], plain)
		assert_eq(PairingCode.from_base32(vectors[plain]).get_string_from_utf8(), plain)


# --- Refused codes ---------------------------------------------------------------


func test_text_that_is_no_code_is_refused() -> void:
	for text: String in ["", "   ", "hello, world!", "189"]:
		assert_eq(PairingCode.decode(text).problem, PairingCode.Problem.NOT_A_CODE, text)


func test_a_changed_or_cut_code_is_refused() -> void:
	var text: String = PairingCode.encode(PairingCode.Kind.OFFER, SESSION, OFFER_SDP)
	var middle: int = text.length() / 2
	var swapped: String = text.substr(0, middle) + ("A" if text[middle] != "A" else "B")
	swapped += text.substr(middle + 1)

	assert_eq(PairingCode.decode(swapped).problem, PairingCode.Problem.DAMAGED, "one character")
	assert_eq(
		PairingCode.decode(text.substr(0, text.length() - 8)).problem,
		PairingCode.Problem.DAMAGED,
		"cut off"
	)
	assert_eq(PairingCode.decode(text.substr(0, 12)).problem, PairingCode.Problem.DAMAGED)


func test_a_code_of_another_version_is_refused_as_such() -> void:
	var text: String = PairingCode.encode(PairingCode.Kind.OFFER, SESSION, OFFER_SDP)
	var data: PackedByteArray = PairingCode.from_base32(text)
	data[0] = PairingCode.FORMAT_VERSION + 1

	var code: PairingCode = PairingCode.decode(PairingCode.to_base32(data))

	assert_eq(code.problem, PairingCode.Problem.OTHER_VERSION)
	assert_true(PairingCode.describe(code.problem).contains("version"))


func test_each_side_takes_only_the_other_sides_code() -> void:
	var offer: String = PairingCode.encode(PairingCode.Kind.OFFER, SESSION, OFFER_SDP)
	var answer: String = PairingCode.encode(PairingCode.Kind.ANSWER, SESSION, OFFER_SDP)
	var foreign: String = PairingCode.encode(PairingCode.Kind.ANSWER, SESSION + 1, OFFER_SDP)

	var host_reads_offer: PairingCode = PairingCode.decode_expected(
		offer, PairingCode.Kind.ANSWER, SESSION
	)
	assert_eq(host_reads_offer.problem, PairingCode.Problem.WRONG_KIND)
	var guest_reads_answer: PairingCode = PairingCode.decode_expected(
		answer, PairingCode.Kind.OFFER, 0
	)
	assert_eq(guest_reads_answer.problem, PairingCode.Problem.WRONG_KIND)
	var host_reads_foreign: PairingCode = PairingCode.decode_expected(
		foreign, PairingCode.Kind.ANSWER, SESSION
	)
	assert_eq(host_reads_foreign.problem, PairingCode.Problem.OTHER_SESSION)
	var guest_reads_offer: PairingCode = PairingCode.decode_expected(
		offer, PairingCode.Kind.OFFER, 0
	)
	assert_eq(guest_reads_offer.problem, PairingCode.Problem.NONE, "a guest takes any offer")
	var host_reads_answer: PairingCode = PairingCode.decode_expected(
		answer, PairingCode.Kind.ANSWER, SESSION
	)
	assert_eq(host_reads_answer.problem, PairingCode.Problem.NONE)


func test_every_problem_has_words_for_the_player() -> void:
	for problem: int in PairingCode.Problem.values():
		var words: String = PairingCode.describe(problem as PairingCode.Problem)
		assert_eq(words.is_empty(), problem == PairingCode.Problem.NONE, str(problem))


# --- Candidates ------------------------------------------------------------------


func test_candidates_go_into_their_media_section() -> void:
	var two_sections: String = OFFER_SDP + "m=application 9 UDP/DTLS/SCTP webrtc-datachannel\r\n"
	two_sections += "a=mid:1\r\n"

	var sdp: String = PairingCode.with_candidates(
		two_sections, [["0", 0, CANDIDATE], ["1", 1, "a=" + CANDIDATE], ["9", 9, CANDIDATE]]
	)

	var lines: PackedStringArray = sdp.split("\r\n", false)
	var second: int = lines.rfind("m=application 9 UDP/DTLS/SCTP webrtc-datachannel")
	assert_eq(lines[second - 2], SHORT_CANDIDATE, "the first section's candidate")
	assert_eq(lines[second - 1], "a=end-of-candidates")
	assert_eq(lines[-2], SHORT_CANDIDATE, "the second section's, without a second a=")
	assert_eq(lines[-1], "a=end-of-candidates")
	assert_eq(sdp.count("a=candidate"), 2, "no section 9")
	assert_true(sdp.ends_with("\r\n"))


func test_what_a_data_channel_does_not_need_is_left_out() -> void:
	var sdp: String = PairingCode.with_candidates(
		OFFER_SDP, [["0", 0, CANDIDATE], ["0", 0, TCP_CANDIDATE], ["0", 0, "candidate:odd"]]
	)

	assert_false(sdp.contains("tcp"), "active TCP candidates cannot meet")
	assert_false(sdp.contains("generation") or sdp.contains("network-cost"), "extensions")
	assert_false(sdp.contains("a=extmap-allow-mixed") or sdp.contains("a=msid-semantic"))
	assert_true(sdp.contains(SHORT_CANDIDATE + "\r\n"))
	assert_true(sdp.contains("a=candidate:odd\r\n"), "a line it cannot read stays as it is")
	for needed: String in ["a=ice-ufrag:", "a=ice-pwd:", "a=fingerprint:", "a=setup:", "a=mid:0"]:
		assert_true(sdp.contains(needed), needed)


func _groups(text: String, size: int) -> PackedStringArray:
	var groups: PackedStringArray = []
	for start: int in range(0, text.length(), size):
		groups.append(text.substr(start, size))
	return groups
