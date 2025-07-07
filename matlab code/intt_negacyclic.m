function a = intt_negacyclic(a_ntt, q)
    n = length(a_ntt);
    zeta = find_primitive_2nth_root(q, n);
    omega_inv = mod_pow(mod_pow(zeta, 2, q), q - 2, q);
    zeta_inv = mod_pow(zeta, q - 2, q);

    for i = 1:n
        a_ntt(i) = mod(a_ntt(i) * mod_pow(zeta_inv, i - 1, q), q);
    end

    a = intt_standard(a_ntt, omega_inv, q);

    for i = 1:n
        a(i) = mod(a(i) * mod_pow(zeta_inv, i - 1, q), q);
    end
end

function a = intt_standard(a, omega_inv, q)
    n = length(a);
    len = n;
    while len > 1
        half = len / 2;
        root = mod_pow(omega_inv, n / len, q);
        for start = 1:len:n
            w = 1;
            for j = 0:(half - 1)
                u = a(start + j);
                v = a(start + j + half);
                a(start + j) = mod(u + v, q);
                a(start + j + half) = mod(w * (u - v + q), q);
                w = mod(w * root, q);
            end
        end
        len = len / 2;
    end
    n_inv = mod_pow(n, q - 2, q);
    for i = 1:n
        a(i) = mod(a(i) * n_inv, q);
    end
end


