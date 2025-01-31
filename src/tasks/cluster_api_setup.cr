require "sam"
require "file_utils"
require "colorize"
require "totem"
require "http/client"
require "halite"
require "./utils/utils.cr"
require "json"
require "yaml"

desc "Install Cluster API for Kind"
task "cluster_api_setup" do |_, args|
  current_dir = FileUtils.pwd

  Halite.follow.get("https://github.com/kubernetes-sigs/cluster-api/releases/download/v1.2.0/clusterctl-linux-amd64") do |response|
    Log.info { "clusterctl response: #{response}" }
    File.write("clusterctl", response.body_io)
  end

  Process.run(
    "sudo chmod +x ./clusterctl",
    shell: true,
    output: stdout = IO::Memory.new,
    error: stderr = IO::Memory.new
  )
  Process.run(
    "sudo mv ./clusterctl /usr/local/bin/clusterctl",
    shell: true,
    output: stdout = IO::Memory.new,
    error: stderr = IO::Memory.new
  )

  Log.info { "Completed downloading clusterctl" }

  clusterctl = Path["~/.cluster-api"].expand(home: true)

  FileUtils.mkdir_p("#{clusterctl}")

  File.write("#{clusterctl}/clusterctl.yaml", "CLUSTER_TOPOLOGY: \"true\"")

  cluster_init_cmd = "clusterctl init --infrastructure docker"
  stdout = IO::Memory.new
  Process.run(cluster_init_cmd, shell: true, output: stdout, error: stdout)
  Log.for("clusterctl init").info { stdout }

  create_cluster_file = "#{current_dir}/capi.yaml"

  create_cluster_cmd = "clusterctl generate cluster capi-quickstart   --kubernetes-version v1.24.0   --control-plane-machine-count=3 --worker-machine-count=3  --flavor development > #{create_cluster_file} "

  Process.run(
    create_cluster_cmd,
    shell: true,
    output: create_cluster_stdout = IO::Memory.new,
    error: create_cluster_stderr = IO::Memory.new
  )

  KubectlClient::Get.wait_for_install_by_apply(create_cluster_file)

  Log.for("clusterctl-create").info { create_cluster_stdout.to_s }
  Log.info { "cluster api setup complete" }
end

desc "Cleanup Cluster API"
task "cluster_api_cleanup" do |_, args|
  current_dir = FileUtils.pwd 
  #KubectlClient::Delete.command("cluster capi-quickstart")
  delete_cluster_file = "#{current_dir}/capi.yaml"
  KubectlClient::Delete.file("#{delete_cluster_file}")

  cmd = "clusterctl delete --all --include-crd --include-namespace"
  Process.run(cmd, shell: true, output: stdout = IO::Memory.new, error: stderr = IO::Memory.new)
end
