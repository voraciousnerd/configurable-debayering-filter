library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity debayer_core is
    port (
        clk    : in std_logic;
        enable : in std_logic;

        N_reg : in integer range 0 to 1024;
        new_image : in std_logic;

        -- 3x3 window
        w00, w01, w02 : in std_logic_vector(7 downto 0);
        w10, w11, w12 : in std_logic_vector(7 downto 0);
        w20, w21, w22 : in std_logic_vector(7 downto 0);

        row_center : in integer;
        col_center : in integer;

        -- outputs
        R_out : out std_logic_vector(7 downto 0);
        G_out : out std_logic_vector(7 downto 0);
        B_out : out std_logic_vector(7 downto 0);

        last_pixel : out std_logic
    );
end entity;

architecture behavioral of debayer_core is

    signal row_lsb : std_logic;
    signal col_lsb : std_logic;

    signal R_reg, G_reg, B_reg : unsigned(7 downto 0) := (others => '0');

    signal last_pixel_s : std_logic := '0';

begin

    --------------------------------------------------------------------
    -- LSB extraction (combinational)
    --------------------------------------------------------------------
    row_lsb <= std_logic(to_unsigned(row_center, 11)(0));
    col_lsb <= std_logic(to_unsigned(col_center, 11)(0));

    --------------------------------------------------------------------
    -- CLOCKED PROCESS
    --------------------------------------------------------------------
    process(clk)

        -- variables for combinational calc inside clock
        variable w00_u, w01_u, w02_u : unsigned(7 downto 0);
        variable w10_u, w11_u, w12_u : unsigned(7 downto 0);
        variable w20_u, w21_u, w22_u : unsigned(7 downto 0);

        variable sum2 : unsigned(8 downto 0);
        variable sum4 : unsigned(9 downto 0);

        variable R_v, G_v, B_v : unsigned(7 downto 0);

    begin
        if rising_edge(clk) then

            if new_image = '1' then
                R_reg        <= (others => '0');
                G_reg        <= (others => '0');
                B_reg        <= (others => '0');
                last_pixel_s <= '0';

            else 

                if enable = '1' then

                    -- convert inputs
                    w00_u := unsigned(w00);
                    w01_u := unsigned(w01);
                    w02_u := unsigned(w02);
                    w10_u := unsigned(w10);
                    w11_u := unsigned(w11);
                    w12_u := unsigned(w12);
                    w20_u := unsigned(w20);
                    w21_u := unsigned(w21);
                    w22_u := unsigned(w22);

                    -- default
                    R_v := (others => '0');
                    G_v := (others => '0');
                    B_v := (others => '0');

                    --------------------------------------------------------
                    -- CASE 1.1: G pixel (ii)
                    --------------------------------------------------------
                    if (row_lsb = '0' and col_lsb = '0')  then

                        G_v := w11_u;

                        sum2 := resize(w10_u,9) + resize(w12_u,9);
                        B_v := sum2(8 downto 1);

                        sum2 := resize(w01_u,9) + resize(w21_u,9);
                        R_v := sum2(8 downto 1);

                    --------------------------------------------------------
                    -- CASE 1.2: G pixel (i)
                    --------------------------------------------------------
                    elsif (row_lsb = '1' and col_lsb = '1') then

                        G_v := w11_u;

                        sum2 := resize(w10_u,9) + resize(w12_u,9);
                        R_v := sum2(8 downto 1);

                        sum2 := resize(w01_u,9) + resize(w21_u,9);
                        B_v := sum2(8 downto 1);

                    --------------------------------------------------------
                    -- CASE 2: B pixel (iv)
                    --------------------------------------------------------
                    elsif (row_lsb = '0' and col_lsb = '1') then

                        B_v := w11_u;

                        sum4 := resize(w01_u,10) + resize(w10_u,10) +
                                resize(w12_u,10) + resize(w21_u,10);
                        G_v := sum4(9 downto 2);

                        sum4 := resize(w00_u,10) + resize(w02_u,10) +
                                resize(w20_u,10) + resize(w22_u,10);
                        R_v := sum4(9 downto 2);

                    --------------------------------------------------------
                    -- CASE 3: R pixel (iii)
                    --------------------------------------------------------
                    else

                        R_v := w11_u;

                        sum4 := resize(w01_u,10) + resize(w10_u,10) +
                                resize(w12_u,10) + resize(w21_u,10);
                        G_v := sum4(9 downto 2);

                        sum4 := resize(w00_u,10) + resize(w02_u,10) +
                                resize(w20_u,10) + resize(w22_u,10);
                        B_v := sum4(9 downto 2);

                    end if;

                    -- register outputs
                    R_reg <= R_v;
                    G_reg <= G_v;
                    B_reg <= B_v;

                end if;
                    
                if (row_center = N_reg-1 and col_center = N_reg-1) then
                    last_pixel_s <= '1';
                end if;
                
            end if;
        end if;


    end process;

    --------------------------------------------------------------------
    -- Outputs
    --------------------------------------------------------------------
    R_out <= std_logic_vector(R_reg);
    G_out <= std_logic_vector(G_reg);
    B_out <= std_logic_vector(B_reg);
    last_pixel <= last_pixel_s;

end architecture;