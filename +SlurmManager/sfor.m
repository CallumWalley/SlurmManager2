classdef SlurmManager
    % SlurmManager Class for managing Slurm jobs within MATLAB.
    %   Detailed explanation goes here
    
    properties
        account;
        cpus_per_task=1;
        mem=1500;
        time=duration(0,15,0);
        pass_workspace=0;
        workspace='.matlab_slurm';
        sdtout; % default = workspace,'out.txt'
        sdterr;
        debug=0;
        dummy=0;
        arrayMax;
        qos='debug';
    end
    methods %(Access='private' )
        function waitOn(obj, jobid, arraysize)
            bar_length = 40;
            throbber = ["/ ", "- ", "\\ ", "| "];
            nthrobber = 1;
            endStr = "";

            if  ~exist('arraysize','var')
                [submitstatus, returnstring]=system(strjoin(['sacct -nj ', jobid, ' --array | wc -l'],''));
                if submitstatus ~= 0
                    error(returnstring);
                end
                arraysize = str2int(returnstring) - 1;
            end
            while 1
                squeuecmd = ['squeue -hj ', jobid, ' --array --format %t'];
                [submitstatus, returnstring]=system(strjoin(squeuecmd,''));
                returnarray = split(returnstring);
                all_count = length(returnarray)-1;
                
                if submitstatus ~= 0
                    error(returnstring);
                end
                
                run_count = nnz(strcmp(returnarray,'R'));
                pend_count = all_count - run_count;

                barSoFar = pad([repmat(char(9615), 1, floor(bar_length*run_count/arraysize))+1, repmat(' ', 1, floor(bar_length*pend_count/arraysize)+1)], bar_length, 'left', char(9608));
                outstring = strjoin([endStr, 'Progress: |', barSoFar, '|  [', throbber(nthrobber), ']'],'');
                fprintf(outstring);
                
                if usejava('desktop')  % Check if GUI or CLI
                    endStr = repelem("\b", strlength(outstring));
                else
                    %endStr = "\033[1F\033[2K\r";
                    endStr = "\r";
                end

                if nthrobber > length(throbber);nthrobber = 1;else; nthrobber = nthrobber + 1; end
                if all_count < 1; break; end             
                pause(10);
            end
        end
    end
    methods
        function obj=SlurmManager()
           disp('New Slurm Manager');
        end
        function sfor(obj, functionHandle, inputArray)

            % TODO: Validate funtion.
            %       Allow multi-input funtions.
            if obj.debug, properties(obj), end

            workspacename = fullfile(obj.workspace, 'workspace.mat');
            handlename = fullfile(obj.workspace, 'handle.m');
            [~,~]=mkdir(obj.workspace);

            save(workspacename);
            save(handlename,'functionHandle');
            mtlbcmd = ['disp(starting MATLAB call);'];
            
            if obj.pass_workspace
                mtlbcmd=[mtlbcmd, "load('", workspacename,"');"];
            end
            mtlbcmd=[mtlbcmd, "load('", handlename,"');",...
                "functionHandle(\${SLURM_ARRAY_TASK_ID});",...
                "disp(starting MATLAB call);"];
            if obj.debug, disp(strjoin(['MATLAB CMD: ',mtlbcmd], '')), end

            % Construct slurm job.
            bshcmd=['matlab -nodisplay -r \"', mtlbcmd, '\"'];
            if obj.debug, disp(strjoin(['BASH CMD: ',bshcmd], '')), end
            arraystr = strrep(mat2str(inputArray),' ',',');
            arraystr = arraystr(2:end-1);
            
            if obj.arrayMax > 0
                    arraystr = [arraystr, '%', num2str(obj.arrayMax)];
            end
            
            cmd = ['sbatch',...
                ' --job-name ', 'test%x',...
                ' --cpus-per-task ', string(obj.cpus_per_task),...
                ' --mem ', string(obj.mem),...
                ' --open-mode ', 'append',...
                ' --time ', char(obj.time),...
                ' --array ', arraystr];
                
                if exist('obj.sdtout','var')
                    cmd = [cmd, ' --output ', obj.sdtout];
                else
                    cmd = [cmd, ' --output ', obj.workspace, '/output.txt'];
                end
                if exist('obj.account','var')
                    cmd = [cmd, ' --account ', obj.account];
                end
                if exist('obj.error','var')
                    cmd = [cmd, ' --error ', obj.error];
                end
                cmd = [cmd, ' --wrap "',  bshcmd, '"'];
                
            
            if obj.debug, disp(strjoin(['FULL CMD: ',cmd], '')), end
            if obj.dummy
                jobidstring=strjoin(cmd, '');
                submitstatus=0;
            else
                [submitstatus, jobidstring]=system(strjoin(cmd, ''));
            end
            if submitstatus
                error(jobidstring);
            end
            jobidarray=split(jobidstring, ' ');
            jobid=strtrim(jobidarray(4));
            disp('Starting Slurm Job array.');
            obj.waitOn(jobid, length(inputArray));
%             chaser_cmd=['srun '];
%             if exist('obj.qos','var')
%                 chaser_cmd = [chaser_cmd, ' --qos ', obj.qos];
%             end
%             chaser_cmd = [chaser_cmd,' --job-name chaser',' --dependency after:',jobid, ' --time ','00:00:01', ' true'];
%             if obj.debug, disp(strjoin(['CHASER CMD: ', chaser_cmd], '')), end
%             [submitstatus, jobidstring]=system(strjoin(chaser_cmd, ''));
%             if submitstatus
%                 error(jobidstring);
%             end
            rmdir(obj.workspace, 's');
        end
    end
end

