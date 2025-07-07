function ntt(varargin)
    if nargin < 2
        fprintf('Usage: ntt length coeff1 coeff2 ... coeffN\n');
        return;
    end

    n = str2double(varargin{1});
    if mod(n, 2) ~= 0 || log2(n) ~= floor(log2(n))
        error('Length must be a power of 2.');
    end

    if length(varargin) ~= n + 1ntt
        error('Expected %d coefficients, got %d.', n, length(varargin) - 1);
    end

    q = 3329;
    a = zeros(1, n);
    for i = 1:n
        a(i) = mod(str2double(varargin{i + 1}), q);
    end

    fprintf('Input vector:\n');
    disp(a);

    [a_ntt, zeta] = ntt_negacyclic(a, q);
    fprintf('zeta = %d\n', zeta);
    fprintf('Negacyclic NTT output:\n');
    disp(a_ntt);

    a_restored = intt_negacyclic(a_ntt, q);
    fprintf('Negacyclic INTT output:\n');
    disp(a_restored);
end
