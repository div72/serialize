module serialize

const max_size = 0x02000000

const (
	max_u16 = 65535
	max_u32 = 4294967295
)

type CompactSize = u64

interface Serializable {
	serialize(mut buf []byte)
	deserialize(mut buf []byte)
}

// Dereference a pointer
/*fn deref<T>(ptr &T) T {
	if isnil(ptr) {
		panic('deref: null pointer')
	}
	return *ptr
}*/

fn serialize_array<T>(obj []T, mut buf []byte) {
	serialize(CompactSize(u64(obj.len)), buf)
	buf.grow_len(sizeof(T) * obj.len)
	for elem in obj {
		serialize(elem, buf)
	}
}

pub fn serialize<T>(obj T, mut buf []byte) {
	//if _unlikely_((int(T) >> 16) & 0xff > 0) {
	//	return serialize(deref(obj))
	//}

	$if T is voidptr {
		panic('serialize: cannot serialize voidptr')
	} $else $if obj is CompactSize {
		if obj < 253 {
			buf << byte(obj)
		} else if obj <= serialize.max_u16 {
			buf.grow_len(3)
			buf << 253
			serialize(u16(obj), buf)
		} else if obj <= serialize.max_u32 {
			buf.grow_len(5)
			buf << 254
			serialize(u32(obj), buf)
		} else {
			buf.grow_len(9)
			buf << 255
			serialize(u64(obj), buf)
		}
	} $else $if T is array {
		serialize_array(obj, buf)
	} $else $if obj is bool || obj is byte || obj is i8 {
		buf << byte(obj)
	} $else $if obj is u16 {
		buf.grow_len(2)
		buf << byte(obj)
		buf << byte(obj & 0xFF00 >> 8)
	} $else $if obj is i16 {
		buf.grow_len(2)
		buf << byte(obj)
		buf << byte(obj & 0xFF00 >> 8)
	} $else $if obj is u32 || obj is int {
		buf.grow_len(4)
		buf << byte(obj)
		buf << byte(obj & 0xFF00 >> 8)
		buf << byte(obj & 0xFF0000 >> 16)
		buf << byte(obj & 0xFF000000 >> 24)
	} $else $if obj is u64 || obj is i64 {
		buf.grow_len(8)
		buf << byte(obj)
		buf << byte(obj & 0xFF00 >> 8)
		buf << byte(obj & 0xFF0000 >> 16)
		buf << byte(obj & 0xFF000000 >> 24)
		buf << byte(obj & 0xFF00000000 >> 32)
		buf << byte(obj & 0xFF0000000000 >> 40)
		buf << byte(obj & 0xFF000000000000 >> 48)
		buf << byte(obj & 0xFF00000000000000 >> 56)
	} $else $if obj is string {
		unsafe {
			obj_ := *(&string(&obj))
		}
		serialize(CompactSize(u64(obj_.len)), mut buf)
		buf.grow_len(obj_.len)
		for i in 0..obj_.len {
			unsafe {
				buf << obj_.str[i]
			}
		}
	} $else $if obj is Serializable {
		buf << obj.serialize(mut buf)
	} $else {
		$for field in T.fields {
			$if field.typ is string {
				mut padded := false
				for attr in field.attrs {
					if attr.starts_with('padded') {
						padded = true
						max_len := attr.split(': ')[1].int()
						if obj.$(field.name).len > max_len {
							panic('serialize: padded string too large')
						}
						for i in 0..obj.$(field.name).len {
							unsafe {
								buf << obj.$(field.name).str[i]
							}
						}
						for _ in 0..(max_len - obj.$(field.name).len) {
							buf << byte(0)
						}
					}
				}
				if !padded {
					serialize<string>(obj.$(field.name), mut buf)
				}
			} $else {
				serialize(obj.$(field.name), mut buf)
			}
		}
	}
}

/*fn deserialize_ptr<T>(_ &T, mut buf []byte) &T {
	ptr := &T{}
	obj := deserialize<T>(mut buf)
	unsafe {
		C.memcpy(ptr, &obj, sizeof(T))
	}
	return ptr
}*/

fn deserialize_array<T>(mut arr []T, mut buf []byte) {
	size := u64(deserialize<CompactSize>(mut buf))
	unsafe {
		arr.grow_len(int(size))
	}
	for _ in 0..size {
		arr << T(deserialize<T>(mut buf))
	}
}

fn deserialize_struct<T>(mut st T, mut buf []byte) {
	$for field in T.fields {
		$if field.typ is voidptr {
			panic('deserialize: cannot deserialize voidptr')
		} $else $if field.typ is string {
			mut padded := false
			for attr in field.attrs {
				if attr.starts_with('padded') {
					padded = true
					max_len := attr.split(': ')[1].int()
					mut len := -1
					for i in 0..len {
						if buf[i] == 0 {
							len = i
						}
					}
					if len == -1 {
						len = max_len
					}
					st.$(field.name) = buf[0..len].bytestr()
					for _ in 0..max_len {
						buf.delete(0)
					}
				}
			}
			if !padded {
				st.$(field.name) = deserialize<string>(mut buf)
			}
		} $else $if field.typ is array {
			deserialize_array(mut st.$(field.name), mut buf)
		} $else $if field.typ is bool {
			st.$(field.name) = deserialize<bool>(mut buf)
		} $else $if field.typ is byte {
			st.$(field.name) = deserialize<byte>(mut buf)
		} $else $if field.typ is i8 {
			st.$(field.name) = deserialize<i8>(mut buf)
		} $else $if field.typ is u16 {
			st.$(field.name) = deserialize<u16>(mut buf)
		} $else $if field.typ is i16 {
			st.$(field.name) = deserialize<i16>(mut buf)
		} $else $if field.typ is u32 {
			st.$(field.name) = deserialize<u32>(mut buf)
		} $else $if field.typ is int {
			st.$(field.name) = deserialize<int>(mut buf)
		} $else $if field.typ is u64 {
			st.$(field.name) = deserialize<u64>(mut buf)
		} $else $if field.typ is i64 {
			st.$(field.name) = deserialize<i64>(mut buf)
		} $else $if field.typ is Serializable {
			st.$(field.name).deserialize(mut buf)
		} $else {
			$if field.typ is T {
				panic('deserialize: recursive struct')
			}
			// deserialize_struct(mut st.$(field.name), mut buf)
			panic('deserialize: nested structs are prohibited for now')
		}
	}
}

pub fn deserialize<T>(mut buf []byte) T {
	$if T is voidptr {
		panic('deserialize: cannot deserialize voidptr')
	} $else $if T is CompactSize {
		match buf[0] {
			253 {
				buf.delete(0)
				return deserialize<u16>(mut buf)
			}
			254 {
				buf.delete(0)
				return deserialize<u32>(mut buf)
			}
			255 {
				buf.delete(0)
				return deserialize<u64>(mut buf)
			}
			else {
				obj := buf[0]
				buf.delete(0)
				return obj
			}
		}
	} $else $if T is string {
		size := deserialize<CompactSize>(mut buf)
		return buf[0..u64(size)].bytestr()
	} $else $if T is array {
		mut arr := T{}
		deserialize_array(mut arr, mut buf)
		return arr
	} $else $if T is bool {
		obj := buf[0] != 0
		buf.delete(0)
		return obj
	} $else $if T is byte {
		obj := buf[0]
		buf.delete(0)
		return obj
	} $else $if T is i8 {
		obj := i8(buf[0])
		buf.delete(0)
		return obj
	} $else $if T is u16 {
		mut obj := T(buf[0])
		obj |= buf[1] << 8
		buf.delete(0)
		buf.delete(0)
		return obj
	} $else $if T is i16 {
		mut obj := T(buf[0])
		obj |= buf[1] << 8
		buf.delete(0)
		buf.delete(0)
		return obj
	} $else $if T is u32 {
		mut obj := T(buf[0])
		obj |= buf[1] << 8
		obj |= buf[2] << 16
		obj |= buf[3] << 24
		buf.delete(0)
		buf.delete(0)
		buf.delete(0)
		buf.delete(0)
		return obj
	} $else $if T is int {
		mut obj := T(buf[0])
		obj |= buf[1] << 8
		obj |= buf[2] << 16
		obj |= buf[3] << 24
		buf.delete(0)
		buf.delete(0)
		buf.delete(0)
		buf.delete(0)
		return obj
	} $else $if T is u64 {
		mut obj := T(buf[0])
		obj |= buf[1] << 8
		obj |= buf[2] << 16
		obj |= buf[3] << 24
		obj |= buf[4] << 32
		obj |= buf[5] << 40
		obj |= buf[6] << 48
		obj |= buf[7] << 56
		buf.delete(0)
		buf.delete(0)
		buf.delete(0)
		buf.delete(0)
		buf.delete(0)
		buf.delete(0)
		buf.delete(0)
		buf.delete(0)
		return obj
	} $else $if T is i64 {
		mut obj := T(buf[0])
		obj |= buf[1] << 8
		obj |= buf[2] << 16
		obj |= buf[3] << 24
		obj |= buf[4] << 32
		obj |= buf[5] << 40
		obj |= buf[6] << 48
		obj |= buf[7] << 56
		buf.delete(0)
		buf.delete(0)
		buf.delete(0)
		buf.delete(0)
		buf.delete(0)
		buf.delete(0)
		buf.delete(0)
		buf.delete(0)
		return obj
	} $else $if T is Serializable {
		mut obj := T{}
		obj.deserialize(mut buf)
		return obj
	} $else {
		mut obj := T{}

		/*if _unlikely_((int(T) >> 16) & 0xff > 0) {
			return deserialize_ptr(obj, mut buf)
		} */

		deserialize_struct<T>(mut obj, mut buf)
		return obj
	}
	panic('This should never happen.')
	return T{}
}