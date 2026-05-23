library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

entity tb_debayer_filter is
end entity;

architecture behavioral of tb_debayer_filter is

    constant N          : integer := 32;
    constant CLK_PERIOD : time := 10 ns;

    -- DUT signals
    signal clk       : std_logic := '1';
    signal rst_n     : std_logic := '0';
    signal new_image : std_logic := '0';
    signal valid_in  : std_logic := '0';
    signal pixel     : std_logic_vector(7 downto 0) := (others => '0');

    signal R         : std_logic_vector(7 downto 0);
    signal G         : std_logic_vector(7 downto 0);
    signal B         : std_logic_vector(7 downto 0);
    signal valid_out : std_logic;
    signal image_finished_s : std_logic;

begin

    --------------------------------------------------------------------
    -- Clock generation
    --------------------------------------------------------------------
    clk <= not clk after CLK_PERIOD/2;

    --------------------------------------------------------------------
    -- DUT instantiation
    --------------------------------------------------------------------
    dut : entity work.debayer_filter
        generic map (
            N => N
        )
        port map (
            clk       => clk,
            rst_n     => rst_n,
            pixel     => pixel,
            valid_in  => valid_in,
            new_image => new_image,
            R         => R,
            G         => G,
            B         => B,
            valid_out => valid_out,
            image_finished   => image_finished_s
        );

    --------------------------------------------------------------------
    -- Stimulus process
    --------------------------------------------------------------------
    stimulus_proc : process
        file input_file    : text;
        variable line_in   : line;
        variable pixel_val : integer;
    begin

        -- Reset
        rst_n <= '0';
        new_image <= '0';
        valid_in <= '0';
        pixel <= (others => '0');

        wait for 3 * CLK_PERIOD;
        rst_n <= '1';
        wait for CLK_PERIOD;

        -- Open input file
        file_open(input_file, "input_32x32.txt", read_mode);

        -- First pixel: new_image = 1 together with valid_in = 1
        readline(input_file, line_in);
        read(line_in, pixel_val);

        pixel     <= std_logic_vector(to_unsigned(pixel_val, 8));
        valid_in  <= '1';
        new_image <= '1';
        wait until rising_edge(clk);

        -- Deassert new_image after one clock
        new_image <= '0';

        -- Remaining pixels
        for i in 1 to N*N - 1 loop
            readline(input_file, line_in);
            read(line_in, pixel_val);

            pixel    <= std_logic_vector(to_unsigned(pixel_val, 8));
            valid_in <= '1';
            wait until rising_edge(clk);
        end loop;

        -- End of input stream
        valid_in <= '0';
        pixel    <= (others => '0');

        file_close(input_file);

        -- Wait enough time for remaining pipeline activity
        wait for (N*N + 4*N + 60) * CLK_PERIOD;

        report "Simulation complete." severity note;
        wait;
    end process;

    --------------------------------------------------------------------
    -- Output capture process
    --------------------------------------------------------------------
    capture_proc : process
        file output_file   : text;
        variable line_out  : line;
        variable r_int     : integer;
        variable g_int     : integer;
        variable b_int     : integer;
    begin
        file_open(output_file, "output_sim.txt", write_mode);

        loop
            wait until rising_edge(clk);

            if valid_out = '1' then
                r_int := to_integer(unsigned(R));
                g_int := to_integer(unsigned(G));
                b_int := to_integer(unsigned(B));

                write(line_out, r_int);
                write(line_out, string'(" "));
                write(line_out, g_int);
                write(line_out, string'(" "));
                write(line_out, b_int);
                writeline(output_file, line_out);
            end if;
        end loop;
    end process;

    --------------------------------------------------------------------
    -- Monitor image_finished
    --------------------------------------------------------------------
    monitor_proc : process
    begin
        loop
            wait until rising_edge(clk);

            if image_finished_s = '1' then
                report "image_finished asserted" severity note;
            end if;
        end loop;
    end process;

end architecture;