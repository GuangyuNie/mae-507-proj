function params = carHuman4DDrivingEnv()

%% Grid setup
params.gmin = [-6.5, -6.5, 0, 0]; % [-4, -4, 0, 0];
params.gmax = [6.5, 6.5, 2*pi, 1]; % [4, 4, 2*pi, 1];
params.gnums = [45, 45, 20, 20];
params.g = createGrid(params.gmin, params.gmax, params.gnums);
params.bdims = {4}; % dimension(s) which contain the belief

%% Control Policy Parameterization Info.
%goal1 = [-5.6, 2.25, pi, 0.01]; % g1 
%goal2 = [-2.25, -5.6, -pi/2, 0.01];  % g2
params.thetas = {[-5.6, 2.25, pi], [-2.25, -5.6, 3*pi/2]};
%params.thetas = {[1.5-6.5, 8.25-6.5, pi], [4.75-6.5, 1.5-6.5, 3*pi/2]};
%params.thetas = {[-3.6, 1, pi], [-1, -3.6, 3*pi/2]};
params.trueThetaIdx = 1;

%% Target Set Setup
tol = 0.1;
if params.trueThetaIdx == 1
    % Since third state is b(theta = 1), then when the true
    % human is optimizing for theta = 1, then target is 
    %       b(theta = 1) = 0.9
    centerPgoal1 = 0.95;
elseif params.trueThetaIdx == 2
    % Since third state is b(theta = 1), then when the true
    % human is optimizing for theta = 2, then target is 
    %       b(theta = 1) = 0.1 --> b(theta = 2) = 0.9
    centerPgoal1 = 0.05;
else 
    error('Invalid true theta index: %f!\n', params.trueThetaIdx);
end
xyoffset = 0.1;
phioffset = 0.01;
center = [0; 0; pi; centerPgoal1];
widths = [(params.gmax(1) - params.gmin(1)) + xyoffset; ...
          (params.gmax(2) - params.gmin(2)) + xyoffset; ...
          (params.gmax(3) - params.gmin(3)) + phioffset; ...
          tol];
% center = [params.thetas{params.trueThetaIdx} centerPgoal1];
% widths = [0.5; ...
%           0.5; ...
%           pi; ...
%           tol];
params.initial_value_fun = shapeRectangleByCenter(params.g, center, widths);

%% Time vector
t0 = 1;
num_timesteps = 25;
params.tau = t0:1:num_timesteps;  % timestep in discrete time is always 1

%% Problem Setup
params.uMode = "max"; % min or max
params.uThresh = 0.23; % 0.16 threshold on P(u | x, g) -- e.g. 0.15;%0.14;%0.13;

%% Plotting?
params.plot = true;        % Visualize the BRS and the optimal trajectory?

%% Pack Reward Info

% 2D Grid for computing Q-function.
g_phys = createGrid(params.gmin(1:3)', ...
                    params.gmax(1:3)', ...
                    params.gnums(1:3)');
params.reward_info.g = g_phys; 

% Obstacles used in Q-function computation.
% Axis-aligned rectangular obstacle convention is:
%       [lower_x, lower_y, width, height]
% params.reward_info.obstacles = {[-4, -4, 2, 2]...
%                                 [2, -4, 2, 2], ...
%                                 [-4, 2, 2, 2], ...
%                                 [2, 2, 2, 2]};
params.reward_info.obstacles = {[0-6.5, 0-6.5, 3, 3]...
                                [0-6.5, 10-6.5, 3, 3], ...
                                [10-6.5, 10-6.5, 3, 3], ...
                                [10-6.5, 0-6.5, 3, 3]};                            
                     
% Setup theta info (convert to cell of cells).                      
params.reward_info.thetas = cell(1,numel(params.thetas));
for i=1:numel(params.thetas)
    params.reward_info.thetas{i} = {params.thetas{i}(1), ...
                                    params.thetas{i}(2), ...
                                    params.thetas{i}(3)};
end

%% Create the Human Dynamical System.
% Initial state and dynamical system setup
params.initial_state = {5.6, 2.25, pi, 0.5};
%params.initial_state = {3.6, 1, pi, 0.5}; 
% params.initial_state = {1.7, -3.5, pi/2, 0.5};
% params.initial_state = {3, 1, pi, 0.5};
% params.initial_state = {0, 0, 0, 0.5};

% Params for Value Iteration. 
params.gamma = 0.98; 
params.eps = 0.01;

% Variance on likelihood model: 
%   beta = 0 --> uniform dist, 
%   beta = 1 --> default 
%   beta = inf --> dirac delta on opt action)
params.beta = 1;

% State space discretization
gdisc4D = (params.gmax - params.gmin) ./ (params.gnums - 1);

% dt induced by discretization
params.vel = 6; % Car's driving speed (m/s)
params.dt = 0.1633; %gdisc4D(1)/params.vel;

% range of belief values
b_space = linspace(params.gmin(params.bdims{1}),params.gmax(params.bdims{1}),params.gnums(params.bdims{1}));
params.b_range = [b_space(2) b_space(numel(b_space)-1)];

% MDP human.
params.dyn_sys = CarHumanBelief4D(params.initial_state, ...
                                    params.reward_info, ...
                                    params.trueThetaIdx, ...
                                    params.uThresh, ...
                                    gdisc4D, ...
                                    params.gnums, ...
                                    params.gamma, ...
                                    params.eps, ...
                                    params.beta, ...
                                    params.vel, ...
                                    params.dt, ...
                                    params.b_range);
         
%% Pack problem parameters
params.schemeData.grid = params.g;
params.schemeData.dynSys = params.dyn_sys;
params.schemeData.uMode = params.uMode;

%% Add obstacles to reachability computation too?
% NOTE: 
% OBSTACLES IN REACHABILITY HAVEN'T BEEN 
% ADDED BASED ON THE NEW OBS LIST!
params.obstaclesInReachability = false;

% obs_center = [-1; 1; 0.5];
% obs_width = [1; ...
%           1; 
%           1.0];
% obstacle_fun = -1 .* shapeRectangleByCenter(g, obs_center, obs_width);
% 
% %% Add obstacles to reachability -- what's this for?
% if existsObstacle
%     extraArgs.obstacles = reward_info.obstacles;
% end
% 
% if params.obstaclesInReachability
%     params.initial_value_fun = max(params.initial_value_fun, obstacle_fun);
% end

%% Pack value function params
params.extraArgs.targets = params.initial_value_fun;
params.extraArgs.stopInit = params.initial_state;

% 'none' or 'set' for backward reachable set (BRS)
% 'minVWithL' for backward reachable tube (BRT)
params.minWith = "minVWithL"; 

%% Optimal control reconstruction params
% Interpolate the value function when computing the opt ctrl?
params.extraArgsCtrl.interpolate = false;
end