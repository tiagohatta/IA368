dqMatrix = [];

% Make sure to have the simulation scene mooc_exercise.ttt running in V-REP!

% simulation setup, will add the matlab paths
connection = simulation_setup();

% the robot we want to interact with
robotNb = 0;

% open the connection
connection = simulation_openConnection(connection, robotNb);

% start simulation if not already started
simulation_start(connection);

vrep=connection.vrep;

% initialize connection
% do a function simulation_getDt to do the following
dt= simulation_getDt(connection)

% now enable stepped simulation mode:
simulation_setStepped(connection,true);

    % given are the functions
    %   r_BF_inB(alpha,beta,gamma) and
    %   J_BF_inB(alpha,beta,gamma)
    % for the foot positon respectively Jacobian
    
    r_BF_inB = @(alpha,beta,gamma)[...
        - sin(beta + gamma) - sin(beta);...
        sin(alpha)*(cos(beta + gamma) + cos(beta) + 1) + 1;...
        -cos(alpha)*(cos(beta + gamma) + cos(beta) + 1)];
    
    J_BF_inB = @(alpha,beta,gamma)[...
        0,             - cos(beta + gamma) - cos(beta),            -cos(beta + gamma);...
        cos(alpha)*(cos(beta + gamma) + cos(beta) + 1), -sin(alpha)*(sin(beta + gamma) + sin(beta)), -sin(beta + gamma)*sin(alpha);...
        sin(alpha)*(cos(beta + gamma) + cos(beta) + 1),  cos(alpha)*(sin(beta + gamma) + sin(beta)),  sin(beta + gamma)*cos(alpha)];
    
    % write an algorithm for the inverse differntial kinematics problem to
    % find the generalized velocities dq to follow a circle in the body xz plane
    % around the start point rCenter with a radius of r=0.5 and a
    % frequeny of 1Hz. The start configuration is q =  pi/180*([0,-60,120])'
    q0 = pi/180*([0,-60,120])';
    %q0 = pi/180*([0,-80,140])';
    
    updatePos(vrep,connection.clientID,q0)
   % pause(1.0)

    dq0 = zeros(3,1);
    rCenter = r_BF_inB(q0(1),q0(2),q0(3));
    radius = 0.5;
    f = 0.25;
    rGoal = @(t) rCenter + radius*[sin(2*pi*f*t),0,cos(2*pi*f*t)]';
    drGoal = @(t) 2*pi*f*radius*[cos(2*pi*f*t),0,-sin(2*pi*f*t)]';
    
    % define here the time resolution
    deltaT = dt;%0.01;
    timeArr = 0:deltaT:1/f;
    
    % q, r, and rGoal are stored for every point in time in the following arrays
    qArr = zeros(3,length(timeArr));
    rArr = zeros(3,length(timeArr));
    rGoalArr = zeros(3,length(timeArr));
    
    q = q0;
    dq = dq0;
    for i=1:length(timeArr)
        t = timeArr(i);
        % data logging, don't change this!
        q = q+deltaT*dq;
        qArr(:,i) = q;
        rArr(:,i) = r_BF_inB(q(1),q(2),q(3));
        rGoalArr(:,i) = rGoal(t);
        
        % controller:
        % step 1: create a simple p controller to determine the desired foot
        % point velocity
        
        % Error = Goal Position in the circle - Current position of the leg.
        err = rGoal(t) - rArr(:,i);
        % Gain for proportional controller, applied to the error.
        % k value was adjusted with comparison to the path for the foot
        % circle.
        k = 16.0; 
        % Calculate foot point velocity
        v = drGoal(t) + k*err;
        
        
        % step 2: perform inverse differential kinematics to calculate the
        % generalized velocities
        
        % Get Moore-Penrose Inverse for the Jacobian J_BF_inB at the current q
        jInv = pinv(J_BF_inB(q(1),q(2),q(3)));
        dq = jInv * v;
        
        updateVels(vrep,connection.clientID,dq)

    end


% now disable stepped simulation mode:
simulation_setStepped(connection,false);

% stop the simulation
simulation_stop(connection);

% close the connection
simulation_closeConnection(connection);