open Unsigned

let () =
	Nvml.init ();
	let count = UInt.to_int (Nvml.Device.get_count ()) in
	(match count with
	| 1 -> Printf.printf "There is %d device installed.\n" count
	| _ -> Printf.printf "There are %d devices installed.\n" count);
	for index = 0 to (count - 1) do
		let device = Nvml.Device.get_handle_by_index ~index:(UInt.of_int index) in
		let name = Nvml.Device.get_name ~device in
		let uuid = Nvml.Device.get_uuid ~device in
		let fan_speed = Nvml.Device.get_fan_speed ~device in
		let memory = Nvml.Device.get_memory_info ~device in
		Printf.printf "--------------------\n";
		Printf.printf "Device index = %d\n" index;
		Printf.printf "Name = %s\n" name;
		Printf.printf "UUID = %s\n" uuid;
		Printf.printf "Fan speed = %d\n" (UInt.to_int fan_speed);
		Printf.printf "Memory total = %d\n"
			(ULLong.to_int (Ctypes.getf memory Nvml.Memory.total));
		Printf.printf "Memory free = %d\n"
			(ULLong.to_int (Ctypes.getf memory Nvml.Memory.free));
		Printf.printf "Memory used = %d\n"
			(ULLong.to_int (Ctypes.getf memory Nvml.Memory.used))
	done;
	Nvml.shutdown ()
