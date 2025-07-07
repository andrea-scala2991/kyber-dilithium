function z = find_primitive_2nth_root(q, n)
    order = 2 * n;
    for z = 2:(q - 1)
        if mod_pow(z, order, q) ~= 1
            continue;
        end
        is_primitive = true;
        for d = 1:(order - 1)
            if mod_pow(z, d, q) == 1
                is_primitive = false;
                break;
            end
        end
        if is_primitive
            return;
        end
    end
    z = 0;
end
