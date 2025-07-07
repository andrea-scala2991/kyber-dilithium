function r = mod_pow(base, exp, q)
    r = 1;
    while exp > 0
        if mod(exp, 2) == 1
            r = mod(r * base, q);
        end
        base = mod(base * base, q);
        exp = floor(exp / 2);
    end
end
