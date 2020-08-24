classdef Job
    % SlurmManager Class for managing Slurm jobs within MATLAB.
    %   Detailed explanation goes here
    
    properties
        % Slurm propeties. 
%         slurm = struct(...         
%             'cpus_per_task',1,...
%             'mem', 1500,...
%             'time',duration(0,15,0),...
%             'sdtout',{},... % default = workspace,'out.txt'
%             'sdterr',{},...
%             'qos',{}...
%         )
        state='UNKNOWN';
        p = inputParser;
%         array;
%         arrayMax;
%         
%         pass_workspace=0;
%         workspace='.matlab_slurm';
% 
%         debug=0;
%         dummy=0; % Print command instead of run.
    end
    
    properties (Access='private' )
         bar_length = 40;
         throbber = ["/ ", "- ", "\\ ", "| "];
    end
    methods (Access='private' )  
        function queue(obj)
            
        end
        function acct(obj)
            
        end
    end
    methods
        function obj=Job(varargin)
            
            addParameter(obj.p,'cpus_per_task',1);
            addParameter(obj.p,'mem',1500);
            addParameter(obj.p,'time',duration(0,15,0));
            addParameter(obj.p,'sdtout','');
            addParameter(obj.p,'stderr','');
            addParameter(obj.p,'qos','');
            
            parse(obj.p, varargin{:});
            disp('New SLURM jobject');          
        end
        function kill(obj)
            squeuecmd = ['skill ', obj];
            [submitstatus, returnstring]=system(strjoin(squeuecmd,''));
            if submitstatus ~= 0
                error(returnstring);
            end
            rmdir(obj.workspace, 's');         
        end
        function waitOn(obj)
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

                barSoFar = pad([repmat(char(9615), 1, floor(obj.bar_length*run_count/arraysize))+1, repmat(' ', 1, floor(obj.bar_length*pend_count/arraysize)+1)], bar_length, 'left', char(9608));
                outstring = strjoin([endStr, 'Progress: |', barSoFar, '|  [', obj.throbber(nthrobber), ']'],'');
                fprintf(outstring);
                
                if usejava('desktop')  % Check if GUI or CLI
                    endStr = repelem("\b", strlength(outstring));
                else
                    %endStr = "\033[1F\033[2K\r";
                    endStr = "\r";
                end

                if nthrobber > length(obj.throbber);nthrobber = 1;else; nthrobber = nthrobber + 1; end
                if all_count < 1; break; end             
                pause(10);
            end
        end
    end
end

