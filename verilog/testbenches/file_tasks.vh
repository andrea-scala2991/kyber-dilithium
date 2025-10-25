`ifndef FILE_TASKS_VH
`define FILE_TASKS_VH
// Common testbench utilities

// Task: Generate test vectors and write to CSV
task automatic generate_input_vectors;
    integer f, i;
    reg [11:0] val;
    begin
        f = $fopen("ntt_test_vectors.csv", "w");

        // Edge cases
        $fwrite(f, "0,0,0,0,0,0,0,0\n");
        $fwrite(f, "3328,3328,3328,3328,3328,3328,3328,3328\n");
        $fwrite(f, "1,1,1,1,1,1,1,1\n");
        $fwrite(f, "0,1,2,3,4,5,6,7\n");
        $fwrite(f, "1664,1664,1664,1664,1664,1664,1664,1664\n");

        // Random vectors
        for (i = 0; i < 100; i = i + 1) begin
            val = $urandom % 3329;
            $fwrite(f, "%0d", val);
            repeat (7) begin
                val = $urandom % 3329;
                $fwrite(f, ",%0d", val);
            end
            $fwrite(f, "\n");
        end

        $fclose(f);
        $display("Generated 'ntt_test_vectors.csv'");
    end
endtask


// Task: Read one vector from CSV into a [7:0] array
task automatic read_next_vector(input integer file, output reg [11:0] vec [7:0], output integer status);
    begin
        status = $fscanf(file, "%d,%d,%d,%d,%d,%d,%d,%d\n",
                         vec[0], vec[1], vec[2], vec[3],
                         vec[4], vec[5], vec[6], vec[7]);
    end
endtask

`endif