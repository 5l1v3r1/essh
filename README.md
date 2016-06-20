# Essh

Essh is an extended ssh client command. The features are the following:

* **Simple**: A single binary CLI tool. Essh simply wraps `ssh` command. You can use it in the same way as `ssh`.
* **Configuration As Code**: You can write SSH client configuration (aka:`~/.ssh/config`) in Lua code. So your ssh_config can become more dynamic.
* **Hooks**: Essh supports hooks that execute commands when it connects a remote server.
* **Servers List Management**: Essh provides utilities for managing hosts, that list and classify servers by using tags.
* **Zsh Completion**: Essh provides built-in zsh completion.
* **Per-Project Configuration**: Essh supports per-project configuration. This allows you to change SSH hosts config by changing current working directory.
* **Task Runner**: Task is a script that runs on remote and local servers. You can use it to automate your system administration tasks.
* **Modules**: Essh provides modular system that allows you to use, create and share reusable Lua code easily.

> **Now Essh is on unstable stage. API and code may be broken in future. And document lacks. sorry!**


**Demo1: Completing a hostname and changing terminal color by using hook.**

![optimized](essh-demo01.gif)

**Simple Configuration Example: `host` and `task`**

```lua
host "web01.localhost" {
    HostName = "192.168.0.11",
    Port = "22",
    User = "kohkimakimoto",
    tags = {
        "web",
    },
}

task "deploy" {
    description = "deploy new application.",
    prefix = true,
    parallel= true,
    targets = "web",
    script = [=[
        cd /path/to/dir
        git clone git@github.com:path/to/app.git
        cd repo
        make
        echo "Done!"
    ]=],
}
```

Are you interesting in Essh? There are documents below. Please start to read **[Getting Started](#getting-started)**.

Table of contents

* [Getting Started](#getting-started)
  * [Installation](#installation)
  * [Using As SSH](#using-as-ssh-client)
  * [Zsh Completion](#zsh-completion)
  * [Using Hooks](#using-hooks)
  * [Managing Hosts](#managing-hosts)
  * [Running Commands](#running-commands)
  * [Running Tasks](#running-tasks)
  * [Using Lua Libraries](#using-lua-libraries)
  * [Using Modules](#using-modules)
  * [Using Drivers](#using-drivers)
  * [Next Steps](#next-steps)
* [Configuration Files](#configuration-files)  
* [Hosts](#hosts)
  * [SSH Config Properties](#ssh-config-properties)
  * [Special Purpose Properties](#special-purpose-properties)
  * [Private Hosts](#private-hosts)
* [Tasks](#tasks)
  * [Properties](#properties)
* [Lua VM](#lua-vm)
  * [Libraries](#libraries)
  * [Predefined Variables](#predefined-variables)
* [Modules](#modules)
  * [Usage](#usage)
  * [Creating Modules](#creating-modules)
* [Drivers](#drivers)
* [Command Line Options](#command-line-options)
  * [Custom Drivers](#custom-drivers)
* [Integrating Other SSH Related Commands](#integrating-other-ssh-related-commands)
* [Author](#author)
* [License](#license)

## Getting Started

This section covers the basic features of Essh. If you are begginer of Essh, I recommend you to read it at first.

### Installation

Essh is provided as a single binary. You can download it and drop it in your $PATH.

[Download latest version](https://github.com/kohkimakimoto/essh/releases/latest)

After installing Essh, run the `essh` without any options in your terminal to check working.

```
$ essh
Usage: essh [<options>] [<ssh options and args...>]

  Essh is an extended ssh command.
  version 0.36.0 (a16744408632097a23bf69e4fa88779d3ab387c4)

  Copyright (c) Kohki Makimoto <kohki.makimoto@gmail.com>
  The MIT License (MIT)

See also:
  essh --help

```

### Using As SSH Client

Essh is implemented as a wrapper of `ssh` command. That means you can completely use Essh in the same way as `ssh`. Try to connect a remote server by using Essh like `ssh` command.

Create `essh.lua` in your current directory. This is a configuration file for Essh. The configuration is written in [Lua](https://www.lua.org/) programming language. Now edit this file as the following.

> Replace the `HostName` and some parameters for your environment.

```lua
host "web01.localhost" {
    ForwardAgent = "yes",
    HostName = "192.168.0.11",
    Port = "22",
    User = "kohkimakimoto",
}

host "web02.localhost" {
    ForwardAgent = "yes",
    HostName = "192.168.0.12",
    Port = "22",
    User = "kohkimakimoto",
}
```

This configuration automatically generates the below ssh config to the temporary file like the `/tmp/essh.ssh_config.260398422` whenever you run `essh`.

```
Host web01.localhost
    ForwardAgent yes
    HostName 192.168.0.11
    Port 22
    User kohkimakimoto

Host web02.localhost
    ForwardAgent yes
    HostName 192.168.0.12
    Port 22
    User kohkimakimoto
```

Essh uses this generated config file by default. If you run the below command

```
$ essh web01.localhost
```

Essh internally runs the `ssh` command like the following.

```
ssh -F /tmp/essh.ssh_config.260398422 web01.localhost
```

Therefore you can connect with a ssh server using Lua config.

Essh also automatically removes the temporary file when the process finishes. So you don't have to be conscious of the real ssh configuration in the normal operations.

### Zsh Completion

Essh supports zsh completion that lists SSH hosts. If you want to use it, add the following code in your `~/.zshrc`

```
eval "$(essh --zsh-completion)"
```

And then, edit your `essh.lua`. Try to add the `description` property as the following.

```lua
host "web01.localhost" {
    ForwardAgent = "yes",
    HostName = "192.168.0.11",
    Port = "22",
    User = "kohkimakimoto",
    -- add description
    description = "web01 development server",
}

host "web02.localhost" {
    ForwardAgent = "yes",
    HostName = "192.168.0.12",
    Port = "22",
    User = "kohkimakimoto",
    -- add description
    description = "web02 development server",
}
```

You will get completion about hosts.

```
$ essh [TAB]
web01.localhost  -- web01 development server
web02.localhost  -- web02 development server
```

You can hide a host using `hidden` property. If you set it true, zsh completion doesn't show the host.

```lua
host "web01.localhost" {
    ForwardAgent = "yes",
    HostName = "192.168.0.11",
    Port = "22",
    User = "kohkimakimoto",
    description = "web01 development server",
    hidden = true,
}
```

You notice that the first characters of the `description` and `hidden` are lower case. Others are upper case. It is important point. Essh uses properties whose first character is upper case, as **ssh_config** generated to the temporary file. And the properties whose first character is lower case are used for special purpose of Essh functions, not ssh config.

For more information on hosts, see the [Hosts](#hosts) section.

### Using Hooks

Hooks in Essh are scripts executed before and after connecting remote servers.

```lua
host "web01.localhost" {
    HostName = "192.168.0.11",
    Port = "22",
    User = "kohkimakimoto",

    hooks = {
        before_connect = "echo before_connect",
        after_connect = "echo after_connect",
        after_disconnect = "echo after_disconnect",
    },
}
```

`before_connect` fires on the localhost before you connect a server via SSH.
`after_connect` fires on the remote host after you connect a server via SSH.
`after_disconnect` fires on the local host after you disconnect from a SSH server.

> Note: I am using this functionality to change OSX terminal profile(color). See the below example.

```lua
host "web01.localhost" {
    -- ...
    hooks = {
        before_connect = "osascript -e 'tell application \"Terminal\" to set current settings of first window to settings set \"Blue Profile\"'",
        after_disconnect = "osascript -e 'tell application \"Terminal\" to set current settings of first window to settings set \"Normal Profile\"'",
    },
}
```

### Managing Hosts

Tags allow you to classify hosts. For instance, edit `essh.lua` to add some hosts and set tags.

```lua
host "web01.localhost" {
    -- ... your config
    description = "web01 development server",
    tags = {
        "web",
    }
}

host "web02.localhost" {
    -- ... your config
    description = "web02 development server",
    tags = {
        "web",
    }
}

host "db01.localhost" {
    -- ... your config
    description = "db01 server",
    tags = {
        "db",
        "backend",
    }
}

host "cache01.localhost" {
    -- ... your config
    description = "cache01 server",
    tags = {
        "cache",
        "backend",
    }
}
```

Run `essh` with `--hosts` option.

```
$ essh --hosts
NAME                 DESCRIPTION                 TAGS             REGISTRY    HIDDEN    SCOPE
cache01.localhost    cache01 server              cache,backend    local                      
db01.localhost       db01 server                 db,backend       local                      
web01.localhost      web01 development server    web              local                      
web02.localhost      web02 development server    web              local                      
```

You can see the all hosts. Next, try to run it with `--select` option.

```
$ essh --hosts --select=web
NAME               DESCRIPTION                 TAGS    REGISTRY    HIDDEN    SCOPE
web01.localhost    web01 development server    web     local                      
web02.localhost    web02 development server    web     local                      
```

You will get filtered hosts by `web` tag. `--select` can be specified multiple times. Each filters are used in OR condition.

```
$ essh --hosts --select=web --select=db
NAME               DESCRIPTION                 TAGS          REGISTRY    HIDDEN    SCOPE
db01.localhost     db01 server                 db,backend    local                      
web01.localhost    web01 development server    web           local                      
web02.localhost    web02 development server    web           local                      
```

For more information on hosts, see the [Hosts](#hosts) section.

### Running Commands

Essh allow you to run commands on the selected remote hosts by using `--exec` and `--on` options.

```
$ essh --exec --backend=remote --target=web uptime
 22:48:31 up  7:58,  0 users,  load average: 0.00, 0.01, 0.03
 22:48:31 up  7:58,  0 users,  load average: 0.00, 0.02, 0.04
```

Use `--prefix` option, Essh outputs result of command with hostname prefix.

```
$ essh --exec --backend=remote --target=web --prefix uptime
[web01.localhost]  22:48:31 up  7:58,  0 users,  load average: 0.00, 0.01, 0.03
[web02.localhost]  22:48:31 up  7:58,  0 users,  load average: 0.00, 0.02, 0.04
```

For more information, see the [Command Line Options](#command-line-options) section.

### Running Tasks

You can define tasks that are executed on remote and local servers.
For example, edit your `essh.lua`.

```lua
task "hello" {
    description = "say hello",
    prefix = true,
    backend = "remote",
    target = "web",
    script = [=[
        echo "hello on $(hostname)"
    ]=],
}
```

Run the task.

```
$ essh hello
[web01.localhost] hello on web01.localhost
[web02.localhost] hello on web02.localhost
```

If you don't specify `local` to `backend` property, Essh runs a task locally.

```lua
task "hello" {
    description = "say hello",
    prefix = true,
    backend = "local",
    script = [=[
        echo "hello on $(hostname)"
    ]=],
}
```

```
$ essh hello
[Local] hello on your-hostname
```

For more information on tasks, see the [Tasks](#tasks) section.

### Using Lua Libraries

Essh uses Lua for configuration and also has several built-in Lua libraries. You can use `require` function to load the libraries.

Example:

```lua
local question = require "glua.question"

task "example" {
    prepare = function ()
        local r = question.ask("Are you OK? [y/N]: ")
        if r ~= "y" then
            -- return false, the task does not run.
            return false
        end
    end,
    script = [=[
        echo "foo"
    ]=],
}
```

`glua.question` is a built-in library of Essh, that is implemented by [gluaquestion](https://github.com/kohkimakimoto/gluaquestion). It provides functions to get user input from a terminal.
And task's property `prepare` is a configuration that defines a function executed when the task starts.

So, You run the task. Essh displays a message and waits your input.

```
$ essh example
Are you OK? [y/N]: y
foo
```

For more information on Lua libraries, see the [Lua VM](#lua-vm) section.

### Using Modules

Essh has a modular system that allows you to use reusable code easily for Essh configuration.
For instance, I provide [bash module](https://github.com/kohkimakimoto/essh/tree/master/modules/bash) that is a collection of bash scripts for using in your Essh tasks.
You can use `essh.require` function to load a module.

Example:

```lua
local bash = essh.require "github.com/kohkimakimoto/essh/modules/bash"

task "example" {
    script = {
        bash.version,
        "echo foo",
    },
}
```

`bash.version` is a variable that actually is a simple string `bash --version`. So this task prints bash version and then runs `echo foo`.

The modules are installed automatically, when you run Essh.
You run the task, you will get as below.

```
$ essh example
Installing module: 'github.com/kohkimakimoto/essh/modules/bash' (into /path/to/directory/.essh)
GNU bash, version 4.1.2(1)-release (x86_64-redhat-linux-gnu)
Copyright (C) 2009 Free Software Foundation, Inc.
License GPLv3+: GNU GPL version 3 or later <http://gnu.org/licenses/gpl.html>

This is free software; you are free to change and redistribute it.
There is NO WARRANTY, to the extent permitted by law.
foo
```

For more information on Modules, see the [Modules](#modules) section.

### Using Drivers

Drivers in Essh are templates to construct script in tasks execution.
Essh usually executes tasks by using built-in default driver. But you can also use your custome drivers.

This is an advanced topic. For more information on Drivers, see the [Drivers](#drivers) section.

### Next Steps

In the [Getting Started](#getting-started) guide. I have explained the basic features of Essh. If you want to get in-depth information about Essh, proceed to the next section.

## Configuration Files

Essh configuration is written in [Lua](https://www.lua.org/). In the configuration files, you can also use DSL syntax that is more human-readable. Here is an example:

```lua
host "web01.localhost" {
    HostName = "192.168.0.11",
    Port = "22",
    User = "kohkimakimoto",
    description = "web01 development server",
    tags = {
        "web",
    },
}

host "web02.localhost" {
    HostName = "192.168.0.12",
    Port = "22",
    User = "kohkimakimoto",
    description = "web02 development server",
    tags = {
        "web",
    },
}

task "uptime" {
    backend = "remote",
    targets = "web",
    script = "uptime",
}
```

Essh loads configuration files from several different places.

* At first, loads `/etc/essh/config.lua` that is the system-wide configuration.
* At second, loads `~/.essh/config.lua` that is the per-user configuration.
* At third, loads `essh.lua` in the current directory for the per-project configuration.
* At last, loads `essh.*.lua` like `essh.dev.lua`, `essh.test.lua` in the current directory for the per-project configuration.

## Hosts

Hosts in Essh are managed SSH servers. Using hosts configuration, Essh dynamically generates SSH config, provides hook functions, classify the hosts by tags.

Example:

```lua
host "web01.localhost" {
    -- SSH config properties.
    HostName = "192.168.0.11",
    Port = "22",
    User = "kohkimakimoto",

    -- Special purpose properties.
    description = "web01 development server",
    hidden = false,
    private = false,
    props = {},
    tags = {},
    hooks = {
        before_connect = "",
        after_connect = "",
        after_disconnect = "",
    },
}
```

Host is composed of two different kinds of properties. **SSH Config Properties** and **Special Purpose Properties**.

### SSH Config Properties

SSH config properties require that the first character is upper case.
For instance `HostName` and `Port`. They are used to generate **ssh_config**. You can use all ssh options to these properties. see ssh_config(5).

### Special Purpose Properties

Special purpose properties require first character is lower case.
They are used for special purpose of Essh functions, not ssh_config.

All the properties of this type are listed below.

* `description` (string): Description is a description of the host.

* `hidden` (boolean): If you set it true, zsh completion doesn't show the host.

* `private` (boolean): If you set it true, This host only can be used to the tasks.

* `hooks` (table): Hooks is a table that defines `before_connect`(string or function), `after_connect`(string or function) and `after_disconnect`(string or function).

    ```lua
    hooks = {
        -- WIP...
    }
    ```

* `tags` (array table): Tags classifys hosts.

    ```lua
    tags = {
        "web",
        "production",
    }
    ```
* `props` (table): Props sets environment variables `ESSH_HOST_PROPS_{KEY}` when the host is used in tasks. The table key is modified to upper cased.

    ```lua
    props = {
        foo = "bar",
    }

    -- ESSH_HOST_PROPS_FOO=bar
    ```

### Private Hosts

You can use `private_host` function as an alias to define a private host. See the below example:

```lua
private_host "example" {
    HostName = "192.168.0.11",
    Port = "22",
    User = "kohkimakimoto",
}
```

This is same the following:

```lua
host "example" {
    HostName = "192.168.0.11",
    Port = "22",
    User = "kohkimakimoto",
    private = true,
}
```

## Tasks

Task is a script that runs on remote and local servers. You can use it to automate your system administration tasks.

Example:

```lua
task "example" {
    description = "example task",
    targets = {
        "web"
    },
    backend = "local",
    parallel = true,
    prefix = true,
    script = {
        "echo foo",
        "echo bar"
    },
}
```

You can run a task below command.

```
$ essh example
```

You can pass an arbitrary string data to the task. This is called payload. See the example:

```
$ essh example hogehoge
```

In the task, You can get the payload from standard input.

```lua
task "example" {
    script = "cat -",
}
```

### Properties

* `description` (string): Description of the task.

* `pty` (boolean): If it is true, SSH connection allocates pseudo-terminal by running ssh command with multiple -t options like `ssh -t -t`.

* `dirver` (string): driver name is used in the task. see [Drivers](#drivers).

* `parallel` (boolean): If it is true, runs task's script in parallel.

* `privileged` (boolean): If it is true, runs task's script by privileged user. If you use it, you have to configure your machine to be able to be used `sudo` without password.

* `disabled` (boolean): If it is true, this task does not run and is not displayed in tasks list.

* `hidden` (boolean): If it is true, this task is not displayed in tasks list.

* `targets` (string|table): Host names and tags that the task's scripts is executed for. You can use only hosts and tags which defined by same configuration registry of the task. If you defines a task in `/var/tmp/example.lua`, This task can not use hosts defined in `~/.essh/config.lua`. The first configuration file is **local** registry. But the second configuration file is **global** registry.

* `backend` (string): You can set value only `remote` or `local`.

* `prefix` (boolean|string): If it is true, Essh displays task's output with hostname prefix. If it is string, Essh displays task's output with custom prefix. This string can be used with text/template format like `{{.Host.Name}}`.

* `prepare` (function): Prepare is a function to be executed when the task starts. See example:

  ```lua
  prepare = function (ctx)
      -- get a payload
      print(ctx:payload())
      -- set a payload
      ctx:payload("new value")
      -- cancel the task execution by returns false.
      return false
  end,
  ```

  Prepare function can have a argument. This argument is a context object of the task. You can get and change the payload by using this context object.
  By the prepare function returns false, you can cancel to execute the task.

* `script` (string|table): Script is an executed code. Example:

  ```lua
  script = [=[
      echo aaa
      echo bbb
      echo ccc
  ]=]
  ```

  or

  ```lua
  script = {
      "echo aaa",
      "echo bbb",
      "echo ccc",
  }
  ```

  If you set it as a table, Essh concatenates strings in the table with newline code. And Essh runs the script as a bash script.
  But this is just default behavior. You can change it by [Drivers](#drivers).

  You can use predefined environment variables in your script, See below:

  * `ESSH_TASK_NAME`: task name.

  * `ESSH_HOST_HOSTNAME`: host name.

  * `ESSH_HOST_SSH_{SSH_CONFIG_KEY}`: ssh_config key/value pare.

  * `ESSH_HOST_TAGS_{TAG}`: tag.

  * `ESSH_HOST_PROPS_{KEY}`: property that is set by host's props. See Hosts [Special Purpose Properties](#special-purpose-properties).

## Lua VM

Essh uses [GopherLua](https://github.com/yuin/gopher-lua) as a Lua VM to load configuration files written in Lua.

### Libraries

Essh provides built-in Lua libraries that you can use in your configuration files.
For instance, if you want to use `essh.json` library, you should use Lua's `require` function like below.

```lua
local json = require("essh.json")

local jsontext = json.encode({aaa = "bbb", ccc = "ddd"})
print(jsontext)
```

The following are the built-in libraries that are included in Essh.

* `glua.json`: Json encoder/decoder. It is implemented by [gluajson](https://github.com/kohkimakimoto/gluajson).
* `glua.fs`: Filesystem utility. It is implemented by [gluafs](https://github.com/kohkimakimoto/gluafs).
* `glua.yaml`: Yaml parser. It is implemented by [gluayaml](https://github.com/kohkimakimoto/gluayaml).
* `glua.template`: Text template. It is implemented by [gluatemplate](https://github.com/kohkimakimoto/gluatemplate).
* `glua.question`: A library to prompt the user for input. It is implemented by [gluaquestion](https://github.com/kohkimakimoto/gluaquestion).
* `glua.http`: Http module. It is implemented by [gluahttp](https://github.com/cjoudrey/gluahttp).

Of course, You can also use another Lua libraries by using `require`. See the Lua's [manual](http://www.lua.org/manual/5.1/manual.html#pdf-require).

### Predefined Variables

Essh provides predefined variables.
In the recent version of Essh, there is one predefined varilable: `essh`.

`essh` is a table that has some functions and variables. see below

* `ssh_config` (string): ssh_config is ssh_config file path. At default, it is a temporary file that is generated automatically when you run Essh. You can overwrite this value for generating ssh_config to a static destination. If you use a gateway host that is a server between your client computer and a target server, you may use this variable to specify `ProxyCommand`. See below example:

    ```lua
    --
    -- network environment.
    -- [your-computer] -- [getway-server1] -- [web-server]
    --

    host "web-server" {
        HostName = "192.168.0.1",
        ProxyCommand = "ssh -q -F " .. essh.ssh_config .. " -W %h:%p getway-server1",
    }
    ```

* `debug` (function): debug is a function to output the debug message. The debug message outputs only when you run Essh with `--debug` option.

  ```lua
  essh.debug("this is a debug message!")
  ```

* `require` (function): require is a function to load Essh module. see the [Module](#module) section.

  ```lua
  local bash = essh.require "github.com/kohkimakimoto/essh/modules/bash"
  ```

## Modules

Module allows you to use, create and share reusable code easily for Essh configuration.

### Usage

Use `essh.require` function to load a module.

```lua
local bash = essh.require "github.com/kohkimakimoto/essh/modules/bash"
```

`essh.require` returns Lua value. In the above case, `bash` is Lua table that has several variables and functions.
You can use `bash` in your configuration.

```lua
local bash = essh.require "github.com/kohkimakimoto/essh//modules/bash"

task "example" {
    script = {
        bash.indent,
        "echo hello | indent",
    },
}
```

`bash.indent` is [this code snippet](https://github.com/kohkimakimoto/essh/blob/master/modules%2Fbash%2Findex.lua#L3-L17).
So the task displays indented output.

`essh.require` is implemented by using [hashicorp/go-getter](https://github.com/hashicorp/go-getter). You can use git url and local filesystem path to specify a module path.

Modules are installed automatically when Essh runs. The installed modules are stored in `.essh` directory. If you need to update installed modules, runs `essh --update`.

```
$ essh --update
```

### Creating Modules

Creating new modules is easy. A minimum module is a directory that includes only `index.lua`.
Try to create `my_module` directory and `index.lua` file in the directory.

```lua
-- my_module/index.lua
local m = {}

m.hello = "echo hello"

return m
```

`index.lua` is the entry-point that have to return Lua value. This example returns a table that has `hello` variable. That's it. To use this module, write below config.

```lua
local my_module = essh.require "./my_module"

task "example" {
    script = {
        my_module.hello,
    },
}
```

Run it.

```
$ essh example
hello
```

If you want to share the module, create a git repository from the module directory and push it to a remote repository as github.com. To use the module of git repository, you update `essh.require` path to the url.

```lua
local my_module = essh.require "github.com/your_account/my_module"

task "example" {
    script = {
        my_module.hello,
    },
}
```

## Drivers

Drivers are templates to construct script in tasks execution.
If you don't specify the driver in the task configuration, Essh uses default built-in driver.

To understand what drivers do, see the following short example:

```lua
task "example" {
    script = {
        "echo aaa",
        "echo bbb",
    }
}
```

Try to run this task with `--debug` option to display the actual script.

```
$ essh example --debug
[essh debug] ...
[essh debug] real local command: [bash -c
export ESSH_TASK_NAME='example'

echo aaa
echo bbb
]
```

According to the debug messages, the task ran the bash script:

```
export ESSH_TASK_NAME='example'

echo aaa
echo bbb
```

This contents was generated by the **built-in driver** that uses task's `script` config.
The built-in driver is the following text template:

```go
{{template "environment" .}}
{{range $i, $script := .Scripts}}{{$script.code}}
{{end}}
```

`{{template "environment" .}}` generates environment variables section. In the above example, this section is

```
export ESSH_TASK_NAME='example'
```

And after that, Essh concatenates `script` texts with new line code. In the above example,

```
echo aaa
echo bbb
```

Conclusion: Drivers are templates for outputting bash script.

### Custom Drivers

You can define and use your custom drivers using `driver` function.

Example:

```lua
driver "my_driver" {
    engine = [=[
        {{template "environment" .}}
        {{range $i, $script := .Scripts}}{{$script.code}}
        {{end}}
    ]=],
}

task "example" {
    driver = "my_driver",
    script = {
        "echo aaa",
        "echo bbb",
    }
}
```

`driver` configuration needs the required parameter `engine`. This is the template text.
To use you custom driver, you need to set task's `driver` property.

See more the example implementation:  [bash.driver](https://github.com/kohkimakimoto/essh/blob/master/modules%2Fbash%2Findex.lua).

## Command Line Options

Please run `essh --help.`

## Integrating Other SSH Related Commands

Essh can be used with `scp`, `rsync` and `git`.

* `git`: To use Essh inside of the git command. Write the following line in your `~/.zshrc`.

  ```
  export GIT_SSH=essh
  ```

* `scp`: Essh support to use with scp.

  ```
  $ essh --scp <scp command args...>
  ```

  For more easy to use, you can run `eval "$(essh --aliases)"` in your `~/.zshrc`, the above code can be written as the following.

  ```
  $ escp <scp command args...>
  ```

* `rsync`: Essh support to use with rsync.

  ```
  $ essh --rsync <rsync command args...>
  ```

  For more easy to use, you can run `eval "$(essh --aliases)"` in your `~/.zshrc`, the above code can be written as the following.

  ```
  $ ersync <rsync command args...>
  ```

## Author

Kohki Makimoto <kohki.makimoto@gmail.com>

## License

The MIT License (MIT)
