function [a_ntt, zeta] = ntt_negacyclic(a, q)
    n = length(a);
    zeta = find_primitive_2nth_root(q, n);
    if zeta == 0
        error('No primitive 2n-th root of unity found for q = %d and n = %d', q, n);
    end
    omega = mod(zeta^2, q);

    for i = 1:n
        a(i) = mod(a(i) * mod_pow(zeta, i - 1, q), q);
    end

    a_ntt = ntt_standard(a, omega, q);

    for i = 1:n
        a_ntt(i) = mod(a_ntt(i) * mod_pow(zeta, i - 1, q), q);
    end
end

function a = ntt_standard(a, omega, q)
    n = length(a);
    len = 2;
    while len <= n
        half = len / 2;
        root = mod_pow(omega, n / len, q);
        for start = 1:len:n
            w = 1;
            for j = 0:(half - 1)
                u = a(start + j);
                v = mod(a(start + j + half) * w, q);
                a(start + j) = mod(u + v, q);
                a(start + j + half) = mod(u - v + q, q);
                w = mod(w * root, q);
            end
        end
        len = len * 2;
    end
end