library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity window_3x3 is
    port (
        clk          : in  std_logic;
        rst_n        : in  std_logic;
        pixel        : in  std_logic_vector(7 downto 0);
        valid_in     : in  std_logic;
        new_image    : in  std_logic;

        image_dim      : in std_logic_vector(10 downto 0);
        image_dim_vld  : in std_logic;

        w00          : out std_logic_vector(7 downto 0);
        w01          : out std_logic_vector(7 downto 0);
        w02          : out std_logic_vector(7 downto 0);
        w10          : out std_logic_vector(7 downto 0);
        w11          : out std_logic_vector(7 downto 0);
        w12          : out std_logic_vector(7 downto 0);
        w20          : out std_logic_vector(7 downto 0);
        w21          : out std_logic_vector(7 downto 0);
        w22          : out std_logic_vector(7 downto 0);

        row_center   : out integer range 0 to 1023;
        col_center   : out integer range 0 to 1023;
        window_valid : out std_logic;
        valid_out    : out std_logic
    );
end entity;

architecture behavioral of window_3x3 is

    component fifo_generator_0
        port (
            clk   : in  std_logic;
            srst  : in  std_logic;
            din   : in  std_logic_vector(7 downto 0);
            wr_en : in  std_logic;
            rd_en : in  std_logic;
            dout  : out std_logic_vector(7 downto 0);
            full  : out std_logic;
            empty : out std_logic
        );
    end component;

    constant N_MAX : integer := 1024; 

    signal N_reg    : integer range 0 to N_MAX := 64; 
    signal config   : std_logic := '0'; 

    signal fifo1_dout  : std_logic_vector(7 downto 0);
    signal fifo2_dout  : std_logic_vector(7 downto 0);
    signal fifo3_dout  : std_logic_vector(7 downto 0);

    signal fifo1_full  : std_logic;
    signal fifo1_empty : std_logic;
    signal fifo2_full  : std_logic;
    signal fifo2_empty : std_logic;
    signal fifo3_full  : std_logic;
    signal fifo3_empty : std_logic;

    -- top row of 3x3 window
    signal r00, r01, r02 : std_logic_vector(7 downto 0) := (others => '0');

    -- middle row of 3x3 window
    signal r10, r11, r12 : std_logic_vector(7 downto 0) := (others => '0');

    -- bottom row of 3x3 window
    signal r20, r21, r22 : std_logic_vector(7 downto 0) := (others => '0');

    signal row_i : integer range 0 to N_MAX-1 := 0;
    signal col_i : integer range 0 to N_MAX-1 := 0;

    signal valid_d : std_logic := '0';
    signal dummy   : std_logic := '0';
    signal rst     : std_logic;

    signal counter : integer range 0 to (N_MAX*N_MAX +2*N_MAX +10) := 0;

    signal wr1, wr2, wr3 : std_logic;
    signal rd1, rd2, rd3 : std_logic;

    -- extra delay
    signal delay : std_logic_vector(7 downto 0) := (others => '0');

    signal fifo_srst : std_logic := '0';

begin

    rst <= not rst_n;

    fifo_srst <= rst or image_dim_vld or config; -- reset FIFOs at the end of each image

    --------------------------------------------------------------------
    -- First line buffer
    --------------------------------------------------------------------
    fifo1_inst : fifo_generator_0
        port map (
            clk   => clk,
            srst  => fifo_srst,
            din   => delay, -- extra delay
            wr_en => wr1,
            rd_en => rd1,
            dout  => fifo1_dout,
            full  => fifo1_full,
            empty => fifo1_empty
        );

    --------------------------------------------------------------------
    -- Second line buffer
    --------------------------------------------------------------------
    fifo2_inst : fifo_generator_0
        port map (
            clk   => clk,
            srst  => fifo_srst,
            din   => fifo1_dout,
            wr_en => wr2,
            rd_en => rd2,
            dout  => fifo2_dout,
            full  => fifo2_full,
            empty => fifo2_empty
        );

    --------------------------------------------------------------------
    -- Third line buffer
    --------------------------------------------------------------------
    fifo3_inst : fifo_generator_0
        port map (
            clk   => clk,
            srst  => fifo_srst,
            din   => fifo2_dout,
            wr_en => wr3,
            rd_en => rd3,
            dout  => fifo3_dout,
            full  => fifo3_full,
            empty => fifo3_empty
        );

    --------------------------------------------------------------------
    -- Counters and horizontal shift registers
    --------------------------------------------------------------------

    process(clk, rst_n)
    begin
        if rst_n = '0' then

            row_i   <= 0;
            col_i   <= 0;
            valid_d <= '0';
            dummy  <= '0';
            counter <= 0;
            config <= '0';
            delay   <= (others => '0');

            wr1 <= '0';
            wr2 <= '0';
            wr3 <= '0';
            rd1 <= '0';
            rd2 <= '0';
            rd3 <= '0';

            r00 <= (others => '0');
            r01 <= (others => '0');
            r02 <= (others => '0');

            r10 <= (others => '0');
            r11 <= (others => '0');
            r12 <= (others => '0');

            r20 <= (others => '0');
            r21 <= (others => '0');
            r22 <= (others => '0');

        elsif rising_edge(clk) then

            if image_dim_vld = '1' then
                N_reg <= to_integer(unsigned(image_dim(10 downto 0)));
                config <= '1';
            end if;

            delay <= pixel; -- extra delay

            if config = '1' then
                row_i   <= 0;
                col_i   <= 0;
                valid_d <= '0';
                dummy  <= '0';
                counter <= 0;
                config <= '0';

                wr1 <= '0';
                wr2 <= '0';
                wr3 <= '0';
                rd1 <= '0';
                rd2 <= '0';
                rd3 <= '0';

                r00 <= (others => '0');
                r01 <= (others => '0');
                r02 <= (others => '0');

                r10 <= (others => '0');
                r11 <= (others => '0');
                r12 <= (others => '0');

                r20 <= (others => '0');
                r21 <= (others => '0');
                r22 <= (others => '0');

            else 

                wr1 <= valid_in;
                if (wr1 = '1') then
                    counter <= counter + 1;
                end if;

                if counter = (N_reg - 1) then
                    rd1 <= '1';
                end if;

                if counter = N_reg then
                    wr2 <= '1';
                end if;

                if counter = (2*N_reg - 1) then
                    rd2 <= '1';
                end if;

                if counter = (2*N_reg) then
                    wr3 <= '1';
                end if; 

                if counter = (3*N_reg - 1) then
                    rd3 <= '1';
                end if;
                

                -- shift 3x3 window
                r00 <= r01;
                r01 <= r02;
                r02 <= fifo3_dout;

                r10 <= r11;
                r11 <= r12;
                r12 <= fifo2_dout;

                r20 <= r21;
                r21 <= r22;
                r22 <= fifo1_dout;

                if counter = 2*N_reg + 2 then
                    dummy <= '1';
                    valid_d <= '1'; -- check gia to synchro tou valid out
                end if;

                -- counters
                if counter >= (2*N_reg + 3) and counter <= (N_reg*N_reg+2*N_reg+3) then -- extra delay to 2 3
                    valid_d <= '1';
                    if col_i = N_reg-1 then
                        col_i <= 0;
                        if row_i = N_reg-1 then
                            row_i <= 0;
                            valid_d <= '0';
                            dummy <= '0';
                        else
                           row_i <= row_i + 1;
                        end if;
                    else
                        col_i <= col_i + 1;
                    end if;
                end if;
            end if; 
        end if;
    end process;

    --------------------------------------------------------------------
    -- Outputs
    --------------------------------------------------------------------
    w00 <= r00 when (col_i /=0 and row_i /= 0) else (others => '0');
    w01 <= r01 when (row_i /= 0) else (others => '0');
    w02 <= r02 when (col_i /= N_reg-1 and row_i /= 0) else (others => '0');

    w10 <= r10 when (col_i /= 0) else (others => '0');
    w11 <= r11;
    w12 <= r12 when (col_i /= N_reg-1) else (others => '0');

    w20 <= r20 when (col_i /= 0 and row_i /= N_reg-1) else (others => '0');
    w21 <= r21 when (row_i /= N_reg-1) else (others => '0');
    w22 <= r22 when (col_i /= N_reg-1 and row_i /= N_reg-1) else (others => '0');

    row_center   <= row_i;
    col_center   <= col_i;
    window_valid <= dummy;
    valid_out   <= valid_d;

end architecture;