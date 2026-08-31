function tests = test_getActImPeaks_single
tests = functiontests(localfunctions);
end

function acceptsSingleActivityImage(testCase)
% Regression test for MATLAB R2024b lsqcurvefit requiring double X0/YDATA.
[x,y] = meshgrid(1:31,1:31);
act = single(0.05*randn(size(x)) + 12*exp(-((x-16).^2+(y-15).^2)/(2*1.2^2)));
theta = getActImPeaks(act,5,[],1);
verifyFalse(testCase,isempty(theta));
end
