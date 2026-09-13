clc;
clear;
close all;

%% ---------------- INPUT SECTION ----------------
L  = input('Enter length of line, L (km)              : ');
r  = input('Enter resistance, R (ohm/km)               : ');
x  = input('Enter reactance, X (ohm/km)                : ');
y  = input('Enter shunt admittance magnitude, Y (mho/km): ');

PR = input('Enter receiving end load, PR (MW)          : ');
VR = input('Enter receiving end voltage, VR (kV, L-L)  : ');
pf = input('Enter receiving end power factor (lagging) : ');


f  = 50;                 % supply frequency, Hz  (given as 50 Hz line)

z = r + 1i*x;             % series impedance per km, ohm/km
yc = 1i*y;                 % shunt admittance per km is purely capacitive, mho/km

%% ---------------- CLASSIFY THE LINE ----------------
% Standard classification used for power lines:
%   Short line  : L < 80 km          -> series impedance only
%   Medium line : 80 <= L < 250 km   -> nominal PI model
%   Long line   : L >= 250 km        -> rigorous (hyperbolic) equations

if L < 80
    lineType = 'SHORT';
elseif L < 250
    lineType = 'MEDIUM';
else
    lineType = 'LONG';
end

fprintf('\n--------------------------------------------------\n');
fprintf('Based on length = %.2f km, the line is classified as: %s LINE\n',L,lineType);
fprintf('--------------------------------------------------\n');

%% ---------------- ABCD PARAMETERS ----------------
Z = z*L;      % total series impedance of the line, ohm
Y = yc*L;     % total shunt admittance of the line, mho

switch lineType
    case 'SHORT'
        % only series impedance is considered, shunt branch neglected
        A = 1;
        B = Z;
        C = 0;
        D = 1;

    case 'MEDIUM'
        % nominal PI model (lumped shunt admittance, half at each end)
        A = 1 + (Y*Z)/2;
        B = Z;
        C = Y*(1 + (Y*Z)/4);
        D = A;

    case 'LONG'
        % rigorous method using propagation constant gamma and
        % characteristic impedance Zc
        gamma = sqrt(z*yc);        % propagation constant per km
        Zc    = sqrt(z/yc);        % characteristic impedance, ohm

        gl = gamma*L;

        A = cosh(gl);
        B = Zc*sinh(gl);
        C = sinh(gl)/Zc;
        D = A;
end

fprintf('\nABCD Parameters of the line:\n');
fprintf('A = %.4f  /_%.3f deg   (per unit)\n',abs(A),angle(A)*180/pi);
fprintf('B = %.4f  /_%.3f deg   (ohm)\n',abs(B),angle(B)*180/pi);
fprintf('C = %.6f  /_%.3f deg   (mho)\n',abs(C),angle(C)*180/pi);
fprintf('D = %.4f  /_%.3f deg   (per unit)\n',abs(D),angle(D)*180/pi);

% quick check, AD - BC should be 1 for a passive, reciprocal network
checkVal = A*D - B*C;
fprintf('\nCheck: AD - BC = %.4f + j%.4f (should be ~1)\n',real(checkVal),imag(checkVal));

%% ---------------- RECEIVING END QUANTITIES ----------------
VRph = (VR*1e3)/sqrt(3);            % receiving end phase voltage, V
VRph = VRph + 1i*0;                  % taken as reference, angle = 0

theta_R = acos(pf);                  % pf is lagging, so current lags voltage
IR = (PR*1e6)/(sqrt(3)*VR*1e3*pf);   % magnitude of receiving end current, A
IR = IR*(cos(-theta_R) + 1i*sin(-theta_R));

%% ---------------- SENDING END QUANTITIES ----------------
VSph = A*VRph + B*IR;     % sending end phase voltage
IS   = C*VRph + D*IR;     % sending end current

VS_LL = sqrt(3)*abs(VSph)/1e3;    % sending end line voltage, kV
IS_mag = abs(IS);

theta_S = angle(VSph) - angle(IS);   % angle between Vs and Is
pf_S = cos(theta_S);
if theta_S > 0
    pfType = 'lagging';
else
    pfType = 'leading';
end

PS = sqrt(3)*VS_LL*1e3*IS_mag*pf_S/1e6;    % sending end active power, MW
QS = sqrt(3)*VS_LL*1e3*IS_mag*sin(theta_S)/1e6; % sending end reactive power, MVAR

%% ---------------- VOLTAGE REGULATION & EFFICIENCY ----------------
% voltage regulation is defined w.r.t no-load receiving end voltage,
% which is Vs/A when the load is removed
VR_noload = abs(VSph)/abs(A);
VoltReg = ((VR_noload - abs(VRph))/abs(VRph))*100;

eff = (PR/PS)*100;

%% ---------------- RESULTS ----------------
fprintf('\n==================== RESULTS ====================\n');
fprintf('Sending end voltage   Vs  = %.3f kV (line)\n',VS_LL);
fprintf('Sending end current   Is  = %.3f A\n',IS_mag);
fprintf('Sending end power     Ps  = %.3f MW\n',PS);
fprintf('Sending end reactive Q_s  = %.3f MVAR\n',QS);
fprintf('Sending end p.f.          = %.4f (%s)\n',pf_S,pfType);
fprintf('Voltage Regulation        = %.3f %%\n',VoltReg);
fprintf('Transmission Efficiency   = %.3f %%\n',eff);
fprintf('===================================================\n');
