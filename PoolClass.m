classdef PoolClass < handle
    properties
        Type
        JobStorageLocation
        Jobs = JobClass.empty

        Host = gethostname
        Shell
        NumWorkers

        reqMemory = 1
        reqWalltime = 1
        initialConfiguration = ''
    endproperties

    properties (Hidden)
        latestJobID = 0

        getSubmitStringFcn
        getSchedulerIDFcn
        getJobStateFcn
        getJobDeleteStringFcn
    endproperties

    properties (Hidden, Access = protected)
        ResourceTemplate = ''
        SubmitArguments
    endproperties

    methods
        function this = PoolClass(configJSON)
            def = jsonread(configJSON);

            this.Type = def.Type;
            this.Shell = def.Shell;
            this.JobStorageLocation = def.JobStorageLocation;
            this.NumWorkers = def.NumWorkers;
            this.ResourceTemplate = def.ResourceTemplate;
            this.SubmitArguments = def.SubmitArguments;

            if isstruct(def.Functions)
                for funcstr = {'SubmitString' 'SchedulerID' 'JobState' 'JobDeleteString'}
                    if isfield(def.Functions, [funcstr{1} 'Fcn'])
                        this.(['get' funcstr{1} 'Fcn']) = str2func(def.Functions.([funcstr{1} 'Fcn']));
                    else
                        this.(['get' funcstr{1} 'Fcn']) = str2func(sprintf('pooldef.%s.%s',def.Name,funcstr{1}));
                    endif
                endfor
            endif

            switch this.Type
                case 'local'
                    datWT = NaN;
                    datMem = NaN;
            endswitch

            this.reqWalltime = datWT;
            this.reqMemory = datMem;
        endfunction

        function set.JobStorageLocation(this,value)
            this.JobStorageLocation = value;
            if isempty(this.JobStorageLocation)
                warning('JobStorageLocation is not specified. The current directory of %s will be used',pwd);
                this.JobStorageLocation = pwd;
            elseif ~exist(this.JobStorageLocation,'dir'), mkdir(this.JobStorageLocation);
            endif
        endfunction

        function set.reqWalltime(this,value)
            if isempty(value), return; endif
            this.reqWalltime = value;
            this.updateSubmitArguments;
        endfunction

        function set.reqMemory(this,value)
            if isempty(value), return; endif
            this.reqMemory = value;
            this.updateSubmitArguments;
        endfunction

        function Job = addJob(this)
            Job = JobClass(this);
            this.Jobs(end+1) = Job;
            this.latestJobID = this.latestJobID + 1;
        endfunction

        function val = get.Jobs(this)
            val = this.Jobs(this.Jobs.isvalid);
        endfunction

    endmethods

    methods (Hidden, Access = protected)
        function updateSubmitArguments(this)
            memory = this.reqMemory;
            walltime = this.reqWalltime;

            switch this.Type
                case 'Slurm'
                    if round(memory) == memory % round
                        memory = sprintf('%dG',memory);
                    else % non-round --> MB
                        memory = sprintf('%dM',memory*1000);
                    end
                    this.SubmitArguments = sprintf('--mem=%s -t %d ',memory,walltime*60);
                case 'Torque'
                    if round(memory) == memory % round
                        memory = sprintf('%dGB',memory);
                    else % non-round --> MB
                        memory = sprintf('%dMB',memory*1000);
                    end
                    this.SubmitArguments = sprintf('-q compute -l mem=%s -l walltime=%d',memory,walltime*3600);
                case 'LSF'
                    this.SubmitArguments = sprintf('-c %d -M %d -R "rusage[mem=%d:duration=%dh]"',walltime*60,memory*1000,memory*1000,walltime);
                case 'Generic'
                    this.SubmitArguments = sprintf('-l s_cpu=%d:00:00 -l s_rss=%dG',walltime,memory);
            endswitch
        endfunction
    endmethods
end