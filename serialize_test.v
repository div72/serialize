module serialize

struct UInt256 {
mut:
	d []byte = []byte{cap: 32}
}

pub fn (mut u UInt256) serialize(mut buf []byte) {
	buf << u.d
}

pub fn (mut u UInt256) deserialize(mut buf []byte) {
	for _ in 0..32 {
		u.d << buf[0]
		buf.delete(0)
	}
}

struct BlockHeader {
	version int
    prev_block_hash Serializable = UInt256{}
    merkle_root_hash Serializable = UInt256{}
    time u32
    bits u32
    nonce u32
}

fn test_stuff() {
	mut serialized := [byte(1), 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 159, 206, 216, 46, 195, 93, 236, 175, 54, 44, 99, 38, 240, 191, 226, 218, 141, 62, 127, 134, 199, 118, 235, 165, 165, 230, 38, 42, 120, 213, 9, 81, 102, 38, 216, 83, 255, 255, 0, 31, 164, 87, 0, 0]
	println(deserialize<BlockHeader>(mut serialized))
	assert serialized.len == 0
}