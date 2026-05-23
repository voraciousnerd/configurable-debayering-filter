library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

-- ---------------------------------------------------------------------------
-- tb_debayer_filter_reconfig
--
-- Tests two consecutive images with DIFFERENT sizes without reset:
--   Image 1 : N = 32  (reads input_32x32.txt,  writes output_sim_32.txt)
--   Image 2 : N = 64  (reads input_64x64.txt,  writes output_sim_64.txt)
--
-- You can adapt N1 / N2 and filenames as needed.
-- ---------------------------------------------------------------------------

entity tb_debayer_filter_reconfig is
end entity;

architecture behavioral of tb_debayer_filter_reconfig is

    constant CLK_PERIOD : time    := 10 ns;
    constant N1         : integer := 32;   -- first image size
    constant N2         : integer := 64;   -- second image size

    -- DUT ports
    signal clk           : std_logic := '1';
    signal rst_n         : std_logic := '0';
    signal image_dim     : std_logic_vector(10 downto 0) := (others => '0');
    signal image_dim_vld : std_logic := '0';
    signal new_image     : std_logic := '0';
    signal valid_in      : std_logic := '0';
    signal pixel         : std_logic_vector(7 downto 0) := (others => '0');

    signal R             : std_logic_vector(7 downto 0);
    signal G             : std_logic_vector(7 downto 0);
    signal B             : std_logic_vector(7 downto 0);
    signal valid_out     : std_logic;
    signal image_finished: std_logic;

begin

    -- Clock
    clk <= not clk after CLK_PERIOD / 2;

    -- DUT
    dut : entity work.debayer_filter
        port map (
            clk            => clk,
            rst_n          => rst_n,
            image_dim      => image_dim,
            image_dim_vld  => image_dim_vld,
            pixel          => pixel,
            valid_in       => valid_in,
            new_image      => new_image,
            R              => R,
            G              => G,
            B              => B,
            valid_out      => valid_out,
            image_finished => image_finished,
            dbg_row_center => open,
            dbg_col_center => open
        );

    -- -----------------------------------------------------------------------
    -- Stimulus
    -- -----------------------------------------------------------------------
    stimulus_proc : process
        file input_file  : text;
        variable line_in : line;
        variable pval    : integer;

        -- Helper: send N*N pixels from a file, with new_image on first pixel
        procedure send_image(
                N_size    : in integer;
                filename  : in string) is
        begin
            file_open(input_file, filename, read_mode);

            -- First pixel: assert new_image for one cycle
            readline(input_file, line_in);
            read(line_in, pval);
            pixel     <= std_logic_vector(to_unsigned(pval, 8));
            valid_in  <= '1';
            new_image <= '1';
            wait until rising_edge(clk);
            new_image <= '0';

            -- Remaining pixels
            for i in 1 to N_size * N_size - 1 loop
                readline(input_file, line_in);
                read(line_in, pval);
                pixel    <= std_logic_vector(to_unsigned(pval, 8));
                valid_in <= '1';
                wait until rising_edge(clk);
            end loop;

            valid_in <= '0';
            pixel    <= (others => '0');
            file_close(input_file);

            wait for (N_size * N_size + 4 * N_size + 60) * CLK_PERIOD;
        end procedure;

    begin
        -- Global reset
        rst_n        <= '0';
        image_dim    <= (others => '0');
        image_dim_vld<= '0';
        valid_in     <= '0';
        new_image    <= '0';
        wait for 4 * CLK_PERIOD;
        rst_n <= '1';
        wait for 5 * CLK_PERIOD;

        -- -------------------------------------------------------------------
        -- Image 1: configure N = N1
        -- -------------------------------------------------------------------
        image_dim     <= std_logic_vector(to_unsigned(N1, 11));
        image_dim_vld <= '1';
        wait until rising_edge(clk);
        image_dim_vld <= '0';
        wait for 5 * CLK_PERIOD;

        send_image(N1, "input_32x32.txt");

        -- -------------------------------------------------------------------
        -- Image 2: reconfigure N = N2 (no reset, same bitstream)
        -- -------------------------------------------------------------------
        image_dim     <= std_logic_vector(to_unsigned(N2, 11));
        image_dim_vld <= '1';
        wait until rising_edge(clk);
        image_dim_vld <= '0';
        wait for 5 * CLK_PERIOD;

        send_image(N2, "input_64x64.txt");

        report "Simulation complete." severity note;
        wait;
    end process;

    -- -----------------------------------------------------------------------
    -- Output capture – writes to two separate files
    -- -----------------------------------------------------------------------
    capture_proc : process
        file out32 : text;
        file out64 : text;
        variable lo : line;
        variable r_i, g_i, b_i : integer;
        variable writing_32 : boolean := true;

    begin
        file_open(out32, "output_sim_32.txt", write_mode);
        file_open(out64, "output_sim_64.txt", write_mode);

        loop
            wait until rising_edge(clk);

            if image_finished = '1' then
                writing_32 := false; 
            end if;

            if valid_out = '1' then
                r_i := to_integer(unsigned(R));
                g_i := to_integer(unsigned(G));
                b_i := to_integer(unsigned(B));

                if writing_32 then
                    write(lo, r_i); write(lo, string'(" "));
                    write(lo, g_i); write(lo, string'(" "));
                    write(lo, b_i);
                    writeline(out32, lo);
                else
                    write(lo, r_i); write(lo, string'(" "));
                    write(lo, g_i); write(lo, string'(" "));
                    write(lo, b_i);
                    writeline(out64, lo);
                end if;
            end if;

        end loop;
    end process;

    -- -----------------------------------------------------------------------
    -- Monitor
    -- -----------------------------------------------------------------------
    monitor_proc : process
    begin
        loop
            wait until rising_edge(clk);
            if image_finished = '1' then
                report "image_finished asserted" severity note;
            end if;
        end loop;
    end process;

end architecture;