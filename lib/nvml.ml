open Ctypes
open Foreign
open Unsigned

let libnvml = Dl.dlopen ~filename:"libnvidia-ml.so" ~flags:[Dl.RTLD_LAZY]

type error =
	| Uninitialized
	| Invalid_argument
	| Not_supported
	| No_permission
	| Already_initialized
	| Not_found
	| Insufficient_size
	| Insufficient_power
	| Driver_not_loaded
	| Timeout
	| IRQ_issue
	| Library_not_found
	| Function_not_found
	| Corrupted_infoROM
	| GPU_is_lost
	| Unknown

exception Error of error

let int_of_error = function
	| Uninitialized -> 1
	| Invalid_argument -> 2
	| Not_supported -> 3
	| No_permission -> 4
	| Already_initialized -> 5
	| Not_found -> 6
	| Insufficient_size -> 7
	| Insufficient_power -> 8
	| Driver_not_loaded -> 9
	| Timeout -> 10
	| IRQ_issue -> 11
	| Library_not_found -> 12
	| Function_not_found -> 13
	| Corrupted_infoROM -> 14
	| GPU_is_lost -> 15
	| Unknown -> 999

let check_error f =
	let fail e = raise (Error e) in
	match f () with
	| 0 -> ()
	| 1 -> fail Uninitialized
	| 2 -> fail Invalid_argument
	| 3 -> fail Not_supported
	| 4 -> fail No_permission
	| 5 -> fail Already_initialized
	| 6 -> fail Not_found
	| 7 -> fail Insufficient_size
	| 8 -> fail Insufficient_power
	| 9 -> fail Driver_not_loaded
	| 10 -> fail Timeout
	| 11 -> fail IRQ_issue
	| 12 -> fail Library_not_found
	| 13 -> fail Function_not_found
	| 14 -> fail Corrupted_infoROM
	| 15 -> fail GPU_is_lost
	| _ -> fail Unknown

let string_of_error' =
	foreign ~from:libnvml "nvmlErrorString" (int @-> returning string)
let string_of_error ~error = string_of_error' (int_of_error error)

let init' = foreign ~from:libnvml "nvmlInit" (void @-> returning int)
let init () = check_error init'

let shutdown' = foreign ~from:libnvml "nvmlShutdown" (void @-> returning int)
let shutdown () = check_error shutdown'

module Util = struct
	(* Extract the contents of the char array into a string. The string will be
	 * terminated by the first null character, if one is present. *)
	let string_of_char_array array =
		let buf = Buffer.create 64 in
		let rec aux array index =
			if index >= Array.length array
			then Buffer.contents buf
			else begin
				let c = Array.get array index in
				if c = '\000'
				then Buffer.contents buf
				else begin
					Buffer.add_char buf c;
					aux array (index + 1)
				end
			end
		in
		aux array 0
end

module System = struct
	(* Bindings to the C functions. *)
	module Foreign = struct
		let get_driver_version =
			foreign ~from:libnvml "nvmlSystemGetDriverVersion"
				(ptr char @-> uint @-> returning int)

		let get_nvml_version =
			foreign ~from:libnvml "nvmlSystemGetNVMLVersion"
				(ptr char @-> uint @-> returning int)

		let get_process_name =
			foreign ~from:libnvml "nvmlSystemGetProcessName"
				(uint @-> ptr char @-> uint @-> returning int)
	end

	(* Functions exposed to the interface. *)
	let get_driver_version () =
		let char_array = Array.make char 80 in
		let char_ptr = Array.start char_array in
		check_error (fun () -> Foreign.get_driver_version char_ptr (UInt.of_int 80));
		Util.string_of_char_array char_array

	let get_nvml_version () =
		let char_array = Array.make char 80 in
		let char_ptr = Array.start char_array in
		check_error (fun () -> Foreign.get_nvml_version char_ptr (UInt.of_int 80));
		Util.string_of_char_array char_array

	let get_process_name ~pid ~length =
		let char_array = Array.make char (UInt.to_int length) in
		let char_ptr = Array.start char_array in
		check_error (fun () -> Foreign.get_process_name pid char_ptr length);
		Util.string_of_char_array char_array
end

module ComputeMode = struct
	type t =
		| Default
		| Exclusive_thread
		| Prohibited
		| Exclusive_process

	let t = 
		let of_int = function
			| 0 -> Default
			| 1 -> Exclusive_thread
			| 2 -> Prohibited
			| 3 -> Exclusive_process
			| _ -> invalid_arg "ComputeMode.t"
		in
		let to_int = function
			| Default -> 0
			| Exclusive_thread -> 1
			| Prohibited -> 2
			| Exclusive_process -> 3
		in
		view ~read:of_int ~write:to_int int
end

module Memory = struct
	type internal_t
	let internal_t : internal_t structure typ = structure "nvmlMemory_t"
	let total = internal_t *:* ullong
	let free = internal_t *:* ullong
	let used = internal_t *:* ullong
	let () = seal internal_t

	type t = {
		total : Unsigned.ullong;
		free : Unsigned.ullong;
		used : Unsigned.ullong;
	}
	let t =
		let of_internal internal = {
			total = getf internal total;
			free = getf internal free;
			used = getf internal used;
		} in
		let to_internal t =
			let internal = make internal_t in
			setf internal total t.total;
			setf internal free t.free;
			setf internal used t.used;
			internal
		in
		view ~read:of_internal ~write:to_internal internal_t

	(* An initialising value for creating non-NULL Memory.t pointers. *)
	let init = {
		total = Unsigned.ULLong.of_int 0;
		free = Unsigned.ULLong.of_int 0;
		used = Unsigned.ULLong.of_int 0;
	}
end

module TemperatureSensors = struct
	type t = GPU

	let t =
		let of_int = function
			| 0 -> GPU
			| _ -> invalid_arg "TemperatureSensors.t"
		in
		let to_int = function
			| GPU -> 0
		in
		view ~read:of_int ~write:to_int int
end

module Utilization = struct
	type internal_t
	let internal_t : internal_t structure typ = structure "nvmlUtilization_t"
	let gpu = internal_t *:* uint
	let memory = internal_t *:* uint
	let () = seal internal_t

	type t = {
		gpu : Unsigned.uint;
		memory : Unsigned.uint;
	}
	let t =
		let of_internal internal = {
			gpu = getf internal gpu;
			memory = getf internal memory;
		} in
		let to_internal t =
			let internal = make internal_t in
			setf internal gpu t.gpu;
			setf internal memory t.memory;
			internal
		in
		view ~read:of_internal ~write:to_internal internal_t

	(* An initialising value for creating non-NULL Utilization.t pointers. *)
	let init = {
		gpu = Unsigned.UInt.of_int 0;
		memory = Unsigned.UInt.of_int 0;
	}
end

module Device = struct
	type internal_t
	let internal_t : internal_t structure typ = structure "nvmlDevice_t"
	let handle = internal_t *:* uint64_t
	let () = seal internal_t

	type t = {
		handle: Unsigned.UInt64.t;
	}
	let t =
		let of_internal internal = {
			handle = getf internal handle;
		} in
		let to_internal t =
			let internal = make internal_t in
			setf internal handle t.handle;
			internal
		in
		view ~read:of_internal ~write:to_internal internal_t

	(* An initialising value for creating non-NULL Device.t pointers. *)
	let init = {
		handle = Unsigned.UInt64.of_int 0;
	}

	(* Bindings to the C functions. *)
	module Foreign = struct
		let get_compute_mode =
			foreign ~from:libnvml "nvmlDeviceGetComputeMode"
				(t @-> ptr ComputeMode.t @-> returning int)

		let get_count =
			foreign ~from:libnvml "nvmlDeviceGetCount" (ptr uint @-> returning int)

		let get_fan_speed =
			foreign ~from:libnvml "nvmlDeviceGetFanSpeed"
				(t @-> ptr uint @-> returning int)

		let get_handle_by_index =
			foreign ~from:libnvml "nvmlDeviceGetHandleByIndex"
				(uint @-> ptr t @-> returning int)

		let get_handle_by_pci_bus_id =
			foreign ~from:libnvml "nvmlDeviceGetHandleByPciBusId"
				(string @-> ptr t @-> returning int)

		let get_handle_by_uuid =
			foreign ~from:libnvml "nvmlDeviceGetHandleByUUID"
				(string @-> ptr t @-> returning int)

		let get_memory_info =
			foreign ~from:libnvml "nvmlDeviceGetMemoryInfo"
				(t @-> ptr Memory.t @-> returning int)

		let get_name =
			foreign ~from:libnvml "nvmlDeviceGetName"
				(t @-> ptr char @-> uint @-> returning int)

		let get_power_usage =
			foreign ~from:libnvml "nvmlDeviceGetPowerUsage"
				(t @-> ptr uint @-> returning int)

		let get_serial =
			foreign ~from:libnvml "nvmlDeviceGetSerial"
				(t @-> ptr char @-> uint @-> returning int)

		let get_temperature =
			foreign ~from:libnvml "nvmlDeviceGetTemperature"
				(t @-> TemperatureSensors.t @-> ptr uint @-> returning int)

		let get_utilization_rates =
			foreign ~from:libnvml "nvmlDeviceGetUtilizationRates"
				(t @-> ptr Utilization.t @-> returning int)

		let get_uuid =
			foreign ~from:libnvml "nvmlDeviceGetUUID"
				(t @-> ptr char @-> uint @-> returning int)

		let get_vbios_version =
			foreign ~from:libnvml "nvmlDeviceGetVbiosVersion"
				(t @-> ptr char @-> uint @-> returning int)

		let on_same_board =
			foreign ~from:libnvml "nvmlDeviceOnSameBoard"
				(t @-> t @-> ptr int @-> returning int)

		let set_compute_mode =
			foreign ~from:libnvml "nvmlDeviceSetComputeMode"
				(t @-> ComputeMode.t @-> returning int)
	end

	(* Generic calls for common getter patterns. *)
	let get_string_generic ~device ~foreign_fn ~length =
		let char_array = Array.make char length in
		let char_ptr = Array.start char_array in
		check_error (fun () -> foreign_fn device char_ptr (UInt.of_int length));
		Util.string_of_char_array char_array

	let get_uint_generic ~device ~foreign_fn =
		let uint_ptr = allocate uint (UInt.of_int 0) in
		check_error (fun () -> foreign_fn device uint_ptr);
		!@ uint_ptr

	(* Functions exposed to the interface. *)
	let get_compute_mode ~device =
		let compute_mode_ptr = allocate ComputeMode.t (ComputeMode.Default) in
		check_error (fun () -> Foreign.get_compute_mode device compute_mode_ptr);
		!@ compute_mode_ptr

	let get_count () =
		let count_ptr = allocate uint (UInt.of_int 0) in
		check_error (fun () -> Foreign.get_count count_ptr);
		!@ count_ptr

	let get_fan_speed ~device =
		get_uint_generic ~device ~foreign_fn:Foreign.get_fan_speed

	let get_handle_by_index ~index =
		let device_ptr = allocate t init in
		check_error (fun () -> Foreign.get_handle_by_index index device_ptr);
		!@ device_ptr

	let get_handle_by_pci_bus_id ~pci_bus_id =
		let device_ptr = allocate t init in
		check_error
			(fun () -> Foreign.get_handle_by_pci_bus_id pci_bus_id device_ptr);
		!@ device_ptr

	let get_handle_by_uuid ~uuid =
		let device_ptr = allocate t init in
		check_error (fun () -> Foreign.get_handle_by_uuid uuid device_ptr);
		!@ device_ptr

	let get_memory_info ~device =
		let memory_ptr = allocate Memory.t Memory.init in
		check_error (fun () -> Foreign.get_memory_info device memory_ptr);
		!@ memory_ptr

	let get_name ~device =
		get_string_generic ~device ~foreign_fn:Foreign.get_name ~length:64

	let get_power_usage ~device =
		get_uint_generic ~device ~foreign_fn:Foreign.get_power_usage

	let get_serial ~device =
		get_string_generic ~device ~foreign_fn:Foreign.get_serial ~length:30

	let get_temperature ~device ~sensor_type =
		let temperature_ptr = allocate uint (UInt.of_int 0) in
		check_error
			(fun () -> Foreign.get_temperature device sensor_type temperature_ptr);
		!@ temperature_ptr

	let get_utilization_rates ~device =
		let utilization_ptr = allocate Utilization.t Utilization.init in
		check_error (fun () -> Foreign.get_utilization_rates device utilization_ptr);
		!@ utilization_ptr

	let get_uuid ~device =
		get_string_generic ~device ~foreign_fn:Foreign.get_uuid ~length:80

	let get_vbios_version ~device =
		get_string_generic ~device ~foreign_fn:Foreign.get_vbios_version ~length:32

	let on_same_board ~device1 ~device2 =
		let on_same_board_ptr = allocate int 0 in
		check_error
			(fun () -> Foreign.on_same_board device1 device2 on_same_board_ptr);
		(!@ on_same_board_ptr) <> 0

	let set_compute_mode ~device ~mode =
		check_error (fun () -> Foreign.set_compute_mode device mode)
end
