sm = SlurmManager();
%sc.debug = 1;
sm.arrayMax = 2;
sm.sfor(@exampleFunction, 1:12);

function exampleFunction(input_)
    disp(input_);
    pause(randi([1,100],1));
end


