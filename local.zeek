@load ./simple-oracle.zeek

# Mirror interface configuration  
redef interface = "enP32780p1s0f0";  # Your actual Mirror interface

# Optimization settings
redef default_file_bsize = 1024*1024;
redef Log::default_rotation_interval = 1hr;
