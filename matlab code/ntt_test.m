q = 3329; %kyber modulus
lengths = [2, 4, 8, 16, 32];

for n = lengths
    fprintf('Testing NTT/INTT for n = %d\n', n);
    a = mod(1:n, q);  % Input: [1, 2, ..., n]
    
    [a_ntt, zeta] = ntt_negacyclic(a, q);
    a_restored = intt_negacyclic(a_ntt, q);
    
    if isequal(a, a_restored)
        fprintf('Success: Restored input matches original.\n\n');
        
        fprintf("zeta for n= %d\n", n);
        disp(zeta);
        
        disp('Original:');
        disp(a);
        
        disp('Restored:');
        disp(a_restored);
    else
        fprintf('Failure: Restored input does not match original.\n');
        
        disp('Original:');
        disp(a);
        disp('Restored:');
        disp(a_restored);
        
        fprintf('\n');
    end
end
