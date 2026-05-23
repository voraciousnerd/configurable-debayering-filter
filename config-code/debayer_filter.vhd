library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity debayer_filter is
    port (
        clk            : in  std_logic;
        rst_n          : in  std_logic;
        pixel          : in  std_logic_vector(7 downto 0);
        valid_in       : in  std_logic;
        new_image      : in  std_logic;

        image_dim      : in std_logic_vector(10 downto 0);
        image_dim_vld  : in std_logic;

        R              : out std_logic_vector(7 downto 0);
        G              : out std_logic_vector(7 downto 0);
        B              : out std_logic_vector(7 downto 0);
        valid_out      : out std_logic;

        dbg_row_center : out integer range 0 to 1023;
        dbg_col_center : out integer range 0 to 1023;
        image_finished   : out std_logic 
    );
end entity;

architecture structural of debayer_filter is

    signal w00_s, w01_s, w02_s : std_logic_vector(7 downto 0);
    signal w10_s, w11_s, w12_s : std_logic_vector(7 downto 0);
    signal w20_s, w21_s, w22_s : std_logic_vector(7 downto 0);

    signal row_center_s   : integer range 0 to 1023;
    signal col_center_s   : integer range 0 to 1023;
    signal window_valid_s : std_logic;
    signal valid_out_init_s      : std_logic;
    signal last_pixel_s    : std_logic;
    signal image_finished_s   : std_logic := '0';
    signal flag   : std_logic := '0';
    signal flag1  : std_logic := '0';
    signal flag2  : std_logic := '0';
    signal delay  : std_logic := '0';

    signal N_reg_s : integer range 0 to 1024 := 64; 

begin

    process (clk, rst_n)
    begin 
        if rst_n = '0' then
            N_reg_s <= 64;
        elsif rising_edge(clk) then
            if image_dim_vld = '1' then
                N_reg_s <= to_integer(unsigned(image_dim(10 downto 0)));
            end if;
        end if;
    end process;

    --------------------------------------------------------------------
    -- 3x3 window generator
    --------------------------------------------------------------------
    window_inst : entity work.window_3x3
        port map (
            clk          => clk,
            rst_n        => rst_n,
            pixel        => pixel,
            valid_in     => valid_in,
            new_image    => new_image,

            image_dim      => image_dim,
            image_dim_vld  => image_dim_vld,
            image_finished => image_finished_s,

            w00          => w00_s,
            w01          => w01_s,
            w02          => w02_s,
            w10          => w10_s,
            w11          => w11_s,
            w12          => w12_s,
            w20          => w20_s,
            w21          => w21_s,
            w22          => w22_s,

            row_center   => row_center_s,
            col_center   => col_center_s,
            window_valid => window_valid_s,
            valid_out    => valid_out_init_s
        );

    --------------------------------------------------------------------
    -- Debayer core
    --------------------------------------------------------------------
    debayer_inst : entity work.debayer_core
        port map (
            clk        => clk,
            enable     => window_valid_s,

            N_reg      => N_reg_s,
            new_image  => new_image,

            w00        => w00_s,
            w01        => w01_s,
            w02        => w02_s,
            w10        => w10_s,
            w11        => w11_s,
            w12        => w12_s,
            w20        => w20_s,
            w21        => w21_s,
            w22        => w22_s,

            row_center => row_center_s,
            col_center => col_center_s,

            R_out      => R,
            G_out      => G,
            B_out      => B,
            last_pixel => last_pixel_s
        );


    process(clk)
    begin
        if rising_edge(clk) then

            flag <= last_pixel_s;

            if rst_n = '0' then
                image_finished_s <= '0';
            end if;

            if valid_out_init_s = '1' then
                flag1 <= '1';
            end if;

            if flag = '1' then
                flag1 <= '0';
            end if;

            if last_pixel_s = '1' then
                image_finished_s <= '1'; 
                flag2 <= '1';
            end if;

            if image_finished_s = '1' or flag2 = '1' then
                image_finished_s <= '0';
                flag2 <= '0';
            end if;
            
        end if;
    end process;

    --------------------------------------------------------------------
    -- Top-level outputs
    --------------------------------------------------------------------
    valid_out      <= flag1;
    dbg_row_center <= row_center_s;
    dbg_col_center <= col_center_s;
    image_finished <= image_finished_s;

end architecture;