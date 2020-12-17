require 'yaml'
require 'optparse'

options = {}
types = {
"CheckConfig" => "check",
"Asset" => "asset",
"Namespace" => "namespace",
"Handler" => "handler",
}

# Fix local.yaml file by adding --- when necessary
def format_local_yaml()
  prev = nil
  index_to_add = Array.new
  n = 0
  ifile = File.open( "local.yaml" )
  local_data = ifile.readlines
  ifile.close
  local_data.each_with_index { |line, index|
    if(index == 0)
      next
    end
    if(line =~ /^type:/)
      if not(prev =~ /---/)
        index_to_add.push(index+n)
        n=n+1
      end
    end
    prev = line
  }
  index_to_add.each { |i|
    local_data.insert(i, '---')
  }
  File.open("local.yaml", "w+") do |f|
    f.puts(local_data)
  end
end

# Prune
def get_changes(types)
  onsensu_yaml = File.open( "sensu.yaml" )
  onsensu = Array.new
  yp = YAML::load_stream( onsensu_yaml ) { |doc|
    if(doc['type'] == 'Namespace')
      onsensu.push("/usr/bin/sensuctl " + types[doc['type']] + " delete " + doc['spec']['name'] + " --skip-confirm")
    else
      onsensu.push("/usr/bin/sensuctl " + types[doc['type']] + " delete " + doc['metadata']['name'] + " --skip-confirm --namespace " + doc['metadata']['namespace'])
    end
  }
 
  local_yaml = File.open( "local.yaml" )
  local = Array.new
  yp = YAML::load_stream( local_yaml ) { |doc|
    if(doc['type'] == 'Namespace')
      local.push("/usr/bin/sensuctl " + types[doc['type']] + " delete " + doc['spec']['name'] + " --skip-confirm")
    else
      local.push("/usr/bin/sensuctl " + types[doc['type']] + " delete " + doc['metadata']['name'] + " --skip-confirm --namespace " + doc['metadata']['namespace'])
    end
  }
 
  to_del = onsensu - local
  to_del.each do |del|
    puts del
  end
end

def prune(logs)
  File.open(logs).each do |line|
    system(line)
  end
end

OptionParser.new do |opts|
  opts.banner = "Usage: prune.rb [options]"

  opts.on("-l", "--logs-only", "Get logs") do |l|
    options[:logs] = l
  end
  opts.on("-p", "--prune", "File with prune commands") do |p|
    options[:prune] = p
  end
end.parse!

if(options[:logs])
  format_local_yaml()
  get_changes(types)
end

if(options[:prune])
  prune(ARGV[0])
end

#t = onsensu.reject{|x| local.include? x}
