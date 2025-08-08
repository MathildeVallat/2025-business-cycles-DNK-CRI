function [HPC,HPG]=hpfilter(X,phi);

long=length(X);         

HP=[1+phi -2*phi phi zeros(1,long-3);...
    -2*phi 1+5*phi -4*phi phi zeros(1,long-4);...
    zeros(long-4,long);...
    zeros(1,long-4) phi -4*phi 1+5*phi -2*phi;...
    zeros(1,long-3) phi -2*phi 1+phi];

for i=3:long-2;
    HP(i,i-2)=phi;
    HP(i,i-1)=-4*phi;
    HP(i,i)=1+6*phi;
    HP(i,i+1)=-4*phi;
    HP(i,i+2)=phi;
end;

HPG=HP\X;
HPC=X-HPG;
