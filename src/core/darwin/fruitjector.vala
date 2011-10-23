public class Zed.Fruitjector : Object {
	public signal void uninjected (uint id);

	/* these should be private, but must be accessible to glue code */
	private MainContext main_context;
	public void * context;
	public Gee.HashMap<uint, void *> instance_by_id = new Gee.HashMap<uint, void *> ();
	public uint last_id;

	construct {
		main_context = MainContext.get_thread_default ();

		context = null;
		last_id++;

		_create_context ();
	}

	~Fruitjector () {
		foreach (var instance in instance_by_id.values)
			_free_instance (instance);
		_destroy_context ();
	}

	public async uint inject (ulong pid, string dylib_path, string data_string) throws IOError {
		var dylib = File.new_for_path (dylib_path);
		if (!dylib.query_exists ())
			throw new IOError.NOT_FOUND ("specified dylib path '" + dylib_path + "' does not exist or cannot be opened");
		if (dylib.query_file_type (FileQueryInfoFlags.NONE) != FileType.REGULAR)
			throw new IOError.NOT_REGULAR_FILE ("specified dylib path '" + dylib_path + "' is not a regular file");
		return _do_inject (pid, dylib_path, data_string);
	}

	public bool any_still_injected () {
		return !instance_by_id.is_empty;
	}

	public bool is_still_injected (uint id) {
		return instance_by_id.has_key (id);
	}

	public void _on_instance_dead (uint id) {
		var source = new IdleSource ();
		source.set_callback (() => {
			void * instance;
			bool instance_id_found = instance_by_id.unset (id, out instance);
			assert (instance_id_found);
			_free_instance (instance);
			uninjected (id);
			return false;
		});
		source.attach (main_context);
	}

	public extern void _create_context ();
	public extern void _destroy_context ();
	public extern void _free_instance (void * instance);
	public extern uint _do_inject (ulong pid, string dylib_path, string data_string) throws IOError;
}